BUCKET  := contact.joev.me
REGION  ?= us-east-1
VCF     := joe_violago.vcf

ifeq ($(REGION),us-east-1)
CREATE_BUCKET_ARGS :=
else
CREATE_BUCKET_ARGS := --create-bucket-configuration LocationConstraint=$(REGION)
endif

.PHONY: provision deploy destroy

provision:
	aws s3api create-bucket \
		--bucket $(BUCKET) \
		--region $(REGION) \
		$(CREATE_BUCKET_ARGS)
	aws s3api put-public-access-block \
		--bucket $(BUCKET) \
		--public-access-block-configuration \
		  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
	aws s3api put-bucket-policy \
		--bucket $(BUCKET) \
		--policy file://infra/bucket-policy.json
	aws s3 website s3://$(BUCKET)/ \
		--index-document $(VCF)

deploy:
	aws s3 cp $(VCF) s3://$(BUCKET)/$(VCF) \
		--content-type "text/vcard" \
		--cache-control "no-cache, no-store, must-revalidate"

destroy:
	aws s3 rm s3://$(BUCKET)/ --recursive
	aws s3api delete-bucket --bucket $(BUCKET)
