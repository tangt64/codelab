import * as pulumi from "@pulumi/pulumi";
import * as command from "@pulumi/command";

const masterIp = "192.168.1.10";
const workerIp = "192.168.1.11";
const sshPrivateKey = "/home/user/.ssh/id_rsa";

// 마스터 초기화
const initMaster = new command.remote.Command("init-master", {
    connection: {
        host: masterIp,
        port: 22,
        user: "root",
        privateKey: require("fs").readFileSync(sshPrivateKey).toString(),
    },
    create: `kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=${masterIp}`,
});

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
    create: getJoinCmd.stdout.apply(joinCmd => `${joinCmd} --v=5`),
}, { dependsOn: [getJoinCmd] });

export const kubeadmJoinCommand = getJoinCmd.stdout;
