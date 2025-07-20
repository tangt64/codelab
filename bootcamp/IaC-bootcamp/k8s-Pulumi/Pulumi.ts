import * as pulumi from "@pulumi/pulumi";
import * as command from "@pulumi/command";

const masterIp = "10.0.2.225";
const workerIp = "10.0.3.19";
const sshPrivateKey = "/root/.ssh/id_rsa";

// 저장소 등록
const addYumRepo = new command.remote.Command("add-yum-repo", {
    connection: {
        host: masterIp,
        port: 22,
        user: "root",
        privateKey: require("fs").readFileSync(sshPrivateKey).toString(),
    },
    create: `cat <<EOF> /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF

dnf makecache
dnf install kubeadm kubectl kubelet -y
`,
});

// 마스터 초기화
const initMaster = new command.remote.Command("init-master", {
    connection: {
        host: masterIp,
        port: 22,
        user: "root",
        privateKey: require("fs").readFileSync(sshPrivateKey).toString(),
    },
    create: `kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${masterIp}`,
}, { dependsOn: [addYumRepo] });

// 마스터 노드의 join 명령어 추출
const getJoinCmd = new command.remote.Command("get-join-command", {
    connection: {
        host: masterIp,
        port: 22,
        user: "root",
        privateKey: require("fs").readFileSync(sshPrivateKey).toString(),
    },
    create: `kubeadm token create --print-join-command`,
}, { dependsOn: [initMaster] });

// 워커 노드에서 join 실행
const joinWorker = new command.remote.Command("join-worker", {
    connection: {
        host: workerIp,
        port: 22,
        user: "root",
        privateKey: require("fs").readFileSync(sshPrivateKey).toString(),
    },
    create: getJoinCmd.stdout.apply((joinCmd: string) => `${joinCmd} --v=5`),
}, { dependsOn: [getJoinCmd] });

export const kubeadmJoinCommand = getJoinCmd.stdout;
