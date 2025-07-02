
package main

import (
    "github.com/gin-gonic/gin"
    "os"
    "os/exec"
    "net/http"
    "fmt"
)

func main() {
    r := gin.Default()
    r.LoadHTMLGlob("templates/*")
    r.Static("/static", "./static")

    r.GET("/", func(c *gin.Context) {
        c.HTML(http.StatusOK, "index.html", nil)
    })

    r.POST("/deploy", func(c *gin.Context) {
        email := c.PostForm("email")
        password := c.PostForm("password")

        cmd := exec.Command("ansible-playbook", "ansible/deploy.yml",
            "-e", fmt.Sprintf("email=%s", email),
            "-e", fmt.Sprintf("password=%s", password))

        cmd.Dir = "/home/tang/vlab-account/horizon-project/account-vlab/gin-backend"

        cmd.Env = append(os.Environ(),
            "ANSIBLE_CONFIG=ansible/ansible.cfg",
            "ANSIBLE_COLLECTIONS_PATHS=~/.ansible/collections:/usr/share/ansible/collections",
            "OS_CLOUD=default",
            "OS_CLIENT_CONFIG_FILE=/home/tang/vlab-account/horizon-project/account-vlab/gin-backend/ansible/clouds.yaml",
        )
        output, err := cmd.CombinedOutput()
        if err != nil {
            c.JSON(http.StatusInternalServerError, gin.H{
                "error":   err.Error(),
                "details": string(output),
            })
            return
        }

        ipPath := fmt.Sprintf("/tmp/iac_output_%s.txt", email[:len(email)-len("@example.com")])
        ipBytes, _ := exec.Command("cat", ipPath).Output()

        c.JSON(http.StatusOK, gin.H{
            "instance_ip": string(ipBytes),
            "console_url": "https://<URL>",
            "login_id":    "",
            "login_pw":    "",
        })
    })

    r.Run(":8080")
}
