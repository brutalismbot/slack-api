.terraform/terraform.zip: | .terraform
	terraform plan -out $@

.terraform:
	terraform init
	terraform fmt

.PHONY: validate plan apply clean clobber

validate: | .terraform
	terraform fmt -check
	terraform validate

plan: validate .terraform/terraform.zip

apply: .terraform/terraform.zip
	terraform apply $<

clean:
	rm -rf .terraform/terraform.zip

clobber: clean
	rm -rf .terraform
