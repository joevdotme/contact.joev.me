BUCKET      := contact.joev.me
REGION      ?= us-east-1
VCF         := joe_violago.vcf
HOSTED_ZONE ?= joev.me

ifeq ($(REGION),us-east-1)
CREATE_BUCKET_ARGS :=
else
CREATE_BUCKET_ARGS := --create-bucket-configuration LocationConstraint=$(REGION)
endif

S3_ENDPOINT := $(BUCKET).s3-website-$(REGION).amazonaws.com

.PHONY: provision s3 dns deploy destroy dns-destroy

provision: s3 dns

s3:
	@if ! aws s3api head-bucket --bucket $(BUCKET) 2>/dev/null; then \
		aws s3api create-bucket \
			--bucket $(BUCKET) \
			--region $(REGION) \
			$(CREATE_BUCKET_ARGS); \
	fi
	aws s3api put-public-access-block \
		--bucket $(BUCKET) \
		--public-access-block-configuration \
		  BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
	aws s3api put-bucket-policy \
		--bucket $(BUCKET) \
		--policy file://infra/bucket-policy.json
	aws s3 website s3://$(BUCKET)/ \
		--index-document $(VCF)

dns:
	@ZONE_ID=$$(aws route53 list-hosted-zones-by-name \
		--dns-name $(HOSTED_ZONE) \
		--query 'HostedZones[0].Id' \
		--output text | cut -d'/' -f3); \
	printf '{"Changes":[{"Action":"UPSERT","ResourceRecordSet":{"Name":"$(BUCKET)","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"$(S3_ENDPOINT)"}]}}]}' | \
	aws route53 change-resource-record-sets \
		--hosted-zone-id $$ZONE_ID \
		--change-batch file:///dev/stdin

deploy:
	aws s3 cp $(VCF) s3://$(BUCKET)/$(VCF) \
		--content-type "text/vcard" \
		--cache-control "no-cache, no-store, must-revalidate"

destroy: dns-destroy
	aws s3 rm s3://$(BUCKET)/ --recursive
	aws s3api delete-bucket --bucket $(BUCKET)

dns-destroy:
	@ZONE_ID=$$(aws route53 list-hosted-zones-by-name \
		--dns-name $(HOSTED_ZONE) \
		--query 'HostedZones[0].Id' \
		--output text | cut -d'/' -f3); \
	printf '{"Changes":[{"Action":"DELETE","ResourceRecordSet":{"Name":"$(BUCKET)","Type":"CNAME","TTL":300,"ResourceRecords":[{"Value":"$(S3_ENDPOINT)"}]}}]}' | \
	aws route53 change-resource-record-sets \
		--hosted-zone-id $$ZONE_ID \
		--change-batch file:///dev/stdin
