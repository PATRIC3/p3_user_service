TOP_DIR = ../..
DEPLOY_RUNTIME ?= /disks/patric-common/runtime
TARGET ?= /tmp/deployment
include $(TOP_DIR)/tools/Makefile.common

SERVICE_SPEC = 
SERVICE_NAME = p3_user_service
SERVICE_HOSTNAME = localhost
SERVICE_PORT = 3002
SERVICE_DIR  = $(SERVICE_NAME)
SERVICE_APP_DIR      = $(TARGET)/services/$(SERVICE_DIR)/app

#APP_REPO     = git@github.com:olsonanl/p3_user.git
#APP_REPO     = https://github.com/olsonanl/p3_user.git
APP_REPO     = https://github.com/PATRIC3/p3_user.git
APP_DIR      = p3_user
APP_SCRIPT   = bin/p3-user

#
# For now we use a fork of dme.
#
DME_REPO     = https://github.com/olsonanl/dme.git


PATH := $(DEPLOY_RUNTIME)/build-tools/bin:$(PATH)

CONFIG          = p3-user.conf
CONFIG_TEMPLATE = $(CONFIG).tt

PRODUCTION = true
MONGO_URL = mongodb://$(SERVICE_HOSTNAME)/p3-user-test

P3USER_SERVICE_URL = http://$(SERVICE_HOSTNAME):$(SERVICE_PORT)
P3HOME_URL = http://$(SERVICE_HOSTNAME):3000
P3USER_SIGNING_PRIVATE_PEM = $(shell pwd)/test-private-nokey.pem
P3USER_SIGNING_PUBLIC_PEM = $(shell pwd)/test-public.pem

USER_TOKEN_DURATION = 4320
SERVICE_TOKEN_DURATION = 4320

SERVICE_PSGI = $(SERVICE_NAME).psgi
TPAGE_ARGS = --define kb_runas_user=$(SERVICE_USER) \
	--define kb_top=$(TARGET) \
	--define kb_runtime=$(DEPLOY_RUNTIME) \
	--define kb_service_name=$(SERVICE_NAME) \
	--define kb_service_dir=$(SERVICE_DIR) \
	--define kb_service_port=$(SERVICE_PORT) \
	--define kb_psgi=$(SERVICE_PSGI) \
	--define kb_app_dir=$(SERVICE_APP_DIR) \
	--define kb_app_script=$(APP_SCRIPT) \
	--define p3user_production=$(PRODUCTION) \
	--define p3user_service_port=$(SERVICE_PORT) \
	--define p3user_mongo_url=$(MONGO_URL) \
	--define p3user_service_url=$(P3USER_SERVICE_URL) \
	--define p3user_signing_private_pem=$(P3USER_SIGNING_PRIVATE_PEM) \
	--define p3user_signing_public_pem=$(P3USER_SIGNING_PUBLIC_PEM) \
	--define p3_home_url=$(P3HOME_URL) \
	--define user_token_duration=$(USER_TOKEN_DURATION) \
	--define service_token_duration=$(SERVICE_TOKEN_DURATION)

# to wrap scripts and deploy them to $(TARGET)/bin using tools in
# the dev_container. right now, these vars are defined in
# Makefile.common, so it's redundant here.
TOOLS_DIR = $(TOP_DIR)/tools
WRAP_PERL_TOOL = wrap_perl
WRAP_PERL_SCRIPT = bash $(TOOLS_DIR)/$(WRAP_PERL_TOOL).sh
SRC_PERL = $(wildcard scripts/*.pl)


default: build-app build-config

build-app:
	if [ ! -f $(APP_DIR)/package.json ] ; then \
		git clone --recursive $(APP_REPO) $(APP_DIR); \
	fi
	if [ ! -f dme/package.json ] ; then \
		git clone --recursive $(DME_REPO) dme; \
	fi
	cd $(APP_DIR); \
		export PATH=$$KB_RUNTIME/build-tools/bin:$$PATH LD_LIBRARY_PATH=$$KB_RUNTIME/build-tools/lib64 ; \
		npm install; \
		npm install forever

dist: 

test: 

deploy: deploy-client deploy-service

deploy-all: deploy-client deploy-service

deploy-client: 

deploy-scripts:
	export KB_TOP=$(TARGET); \
	export KB_RUNTIME=$(DEPLOY_RUNTIME); \
	export KB_PERL_PATH=$(TARGET)/lib bash ; \
	for src in $(SRC_PERL) ; do \
		basefile=`basename $$src`; \
		base=`basename $$src .pl`; \
		echo install $$src $$base ; \
		cp $$src $(TARGET)/plbin ; \
		$(WRAP_PERL_SCRIPT) "$(TARGET)/plbin/$$basefile" $(TARGET)/bin/$$base ; \
	done

deploy-service: deploy-run-scripts deploy-app deploy-config

deploy-app: build-app
	-mkdir $(SERVICE_APP_DIR)
	rsync --delete -arv $(APP_DIR)/. $(SERVICE_APP_DIR)

deploy-config: build-config
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(SERVICE_APP_DIR)/$(CONFIG)

build-config:
	$(TPAGE) $(TPAGE_ARGS) $(CONFIG_TEMPLATE) > $(APP_DIR)/$(CONFIG)

deploy-run-scripts:
	mkdir -p $(TARGET)/services/$(SERVICE_DIR)
	$(TPAGE) $(TPAGE_ARGS) service/start_service.tt > $(TARGET)/services/$(SERVICE_DIR)/start_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/start_service
	$(TPAGE) $(TPAGE_ARGS) service/stop_service.tt > $(TARGET)/services/$(SERVICE_DIR)/stop_service
	chmod +x $(TARGET)/services/$(SERVICE_DIR)/stop_service
	if [ -f service/upstart.tt ] ; then \
		$(TPAGE) $(TPAGE_ARGS) service/upstart.tt > service/$(SERVICE_NAME).conf; \
	fi
	echo "done executing deploy-service target"

deploy-upstart: deploy-service
	-cp service/$(SERVICE_NAME).conf /etc/init/
	echo "done executing deploy-upstart target"

deploy-cfg:

deploy-docs:
	-mkdir -p $(TARGET)/services/$(SERVICE_DIR)/webroot/.
	cp docs/*.html $(TARGET)/services/$(SERVICE_DIR)/webroot/.


build-libs:

include $(TOP_DIR)/tools/Makefile.common.rules
