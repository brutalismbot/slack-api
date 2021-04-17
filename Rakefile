require "dotenv/load"
require "rake/clean"
CLEAN.include ".terraform"
task :default => %i[terraform:plan]

namespace :terraform do
  %i[plan apply].each do |cmd|
    desc "Run terraform #{ cmd }"
    task cmd => :init do
      sh %{terraform #{ cmd }}
    end
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
