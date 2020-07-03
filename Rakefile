require "rake/clean"

task :default => %i[terraform:plan]
CLOBBER.include ".terraform"
CLEAN.include ".terraform/terraform.zip"

namespace :terraform do
  directory ".terraform" do
    sh "terraform init"
  end

  desc "Run terraform init"
  task :init => %w[.terraform]

  ".terraform/terraform.zip".tap do |planfile|

    file planfile => %w[terraform.tf], order_only: %w[.terraform] do
      sh "terraform plan -out #{planfile}"
    end

    desc "Run terraform apply"
    task :apply => [planfile] do
      sh "terraform apply #{planfile}"
    end

    desc "Run terraform plan"
    task :plan => [planfile]
  end
end
