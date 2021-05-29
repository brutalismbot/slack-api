require "dotenv/load"
require "rake/clean"
CLEAN.include ".terraform"
task :default => %i[terraform:plan]

desc "Install app"
task :install do
  sh %{open https://api.brutalismbot.com/slack/v2/install}
end

namespace :terraform do
  desc "Run terraform plan"
  task :plan => :init do
    sh %{terraform plan -detailed-exitcode}
  end

  desc "Run terraform apply"
  task :apply => :init do
    sh %{terraform apply}
  end

  namespace :apply do
    desc "Run terraform auto -auto-approve"
    task :auto => :init do
      sh %{terraform apply -auto-approve}
    end
  end

  task :init => ".terraform"

  directory ".terraform" do
    sh %{terraform init}
  end
end
