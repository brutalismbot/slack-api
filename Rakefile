require "rake/clean"
CLOBBER.include ".terraform"
CLEAN.include "terraform.zip"
task :default => %i[terraform:plan]

namespace :terraform do
  directory ".terraform" do
    sh "terraform init"
  end

  desc "Run terraform init"
  task :init => %i[.terraform]

  file "terraform.zip" => %i[terraform.tf], order_only: %i[.terraform] do
    sh "terraform plan -out terraform.zip"
  end

  desc "Run terraform apply"
  task :apply => %i[terraform.zip] do
    sh "terraform apply terraform.zip"
    rm "terraform.zip"
  end

  desc "Run terraform plan"
  task :plan => %i[terraform.zip]
end
