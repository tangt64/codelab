REGION ?= ap-northeast-2
STACK ?= demo
.PHONY: bootstrap deploy clean test

bootstrap:
	./common/scripts/bootstrap.sh $(REGION)

deploy-%:
	./common/scripts/deploy.sh $(REGION) $*

test-%:
	./common/scripts/test.sh $(REGION) $*

clean-%:
	./common/scripts/clean.sh $(REGION) $*

clean-all:
	./common/scripts/clean_all.sh $(REGION)
