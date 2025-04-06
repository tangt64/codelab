CA_KEY=output/ca.key
CA_CERT=output/ca.crt
CA_CONF=ca.conf

LEAF_KEY=output/rancher.key
LEAF_CSR=output/rancher.csr
LEAF_CERT=output/rancher.crt
LEAF_CONF=san.conf

.PHONY: all clean ca leaf
all: ca leaf
## 루트 CA 생성
ca:
	mkdir -p output
	openssl genrsa -out $(CA_KEY) 4096
	openssl req -x509 -new -nodes -key $(CA_KEY) -sha256 -days 3650 \
		-out $(CA_CERT) -config $(CA_CONF) -extensions v3_ca
	@echo "✅ [CA 생성 완료] $(CA_CERT)"
## 리프(leaf) 인증서 생성
leaf:
	mkdir -p output
	openssl req -new -nodes -out $(LEAF_CSR) -newkey rsa:2048 -keyout $(LEAF_KEY) -config $(LEAF_CONF)
	openssl x509 -req -in $(LEAF_CSR) -CA $(CA_CERT) -CAkey $(CA_KEY) -CAcreateserial \
		-out $(LEAF_CERT) -days 825 -sha256 -extfile $(LEAF_CONF) -extensions req_ext
	@echo "✅ [Leaf 인증서 생성 완료] $(LEAF_CERT)"
## 정리
clean:
	rm -rf output
	@echo "🧹 모든 생성 파일 삭제됨."
