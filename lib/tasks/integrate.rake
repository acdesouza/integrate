if Kernel.const_defined? :Rails
  task 'integration:clear_before_pull' => [ 'log:clear', 'tmp:clear' ]

  task 'integration:test:prepare' => [
    'db:drop', 'db:create', 'db:schema:load',
    'db:migrate', 'db:seed', 'db:test:prepare'
  ]
else
  task 'integration:clear_before_pull'
  task 'integration:test:prepare'
end

def sh_with_clean_env(cmd)
  Bundler.with_unbundled_env do
    puts cmd

    return `#{cmd}`
  end
end

desc 'Run all integration process: pull, migration, ' +
  'specs with coverage, push and deploy (with lock/unlock strategy)'
task integrate: [
  'integration:environment',
  'integration:git:status_check',
  'integration:grant_no_one_else_is_integrating',
  'integration:clear_before_pull',
  'integration:git:pull',
  'integration:bundle_install',
  'integration:test',
  'integration:git:master_branch_check',
  'integration:git:promote_master_to_staging',
  'integration:git:push',
  'integration:lock',
  'integration:deploy',
  'integration:unlock'
]

desc 'Promote stage environment to production, ' +
     'checks coverage and tests'
task promote_staging_to_production: [
  'integration:set_production_as_deploy_env',
  'integration:environment',
  'integration:git:status_check',
  'integration:grant_no_one_else_is_integrating',
  'integration:clear_before_pull',
  'integration:git:pull',
  'integration:git:master_branch_check',
  'integration:git:promote_staging_to_production',
  'integration:git:push',
  'integration:db:backup',
  'integration:lock',
  'integration:deploy',
  'integration:unlock'
]

namespace :integration do
  task :set_production_as_deploy_env do
    ENV['APP_ENV'] ||= 'production'
  end

  task :environment do
    if Kernel.const_defined? :Rails
      PROJECT   = ENV['PROJECT'  ] || Rails.application.class.module_parent_name.underscore
      RAILS_ENV = ENV['RAILS_ENV'] || 'development'
    else
      PROJECT   = ENV['PROJECT'  ] || `git remote show origin -n | grep "Fetch URL:" | sed "s#^.*/\\(.*\\)\\(\\.git\\)*#\\1#"`.chomp
      RACK_ENV  = ENV['RACK_ENV' ] || 'development'
    end

    USER           = `whoami`.chomp
    APP_ENV        = ENV['APP_ENV'] || 'staging'
    APP            = "#{PROJECT}-#{APP_ENV}"
    DEPLOY_GIT_URL = ENV['DEPLOY_GIT_URL'] || "git@heroku.com:"
  end

  task test: 'integration:test:prepare' do
    cmd = Kernel.const_defined?(:Rails) ? 'rails test -f' : 'rake test'
    system("#{cmd} RAILS_ENV=test RACK_ENV=test")
    raise 'tests failed' unless $?.success?
  end

  task :lock do
    sh_with_clean_env "heroku config:add INTEGRATING_BY=#{USER} --app #{APP}"
  end

  task :unlock do
    sh_with_clean_env "heroku config:remove INTEGRATING_BY --app #{APP}"
  end

  task :grant_no_one_else_is_integrating do
    x = sh_with_clean_env("heroku config:get INTEGRATING_BY --app #{APP}").chomp

    if x.present? && x != USER
      puts "\"#{x}\" is already integrating app #{APP}"
      exit
    end
  end

  task 'deploy' do
    puts "-----> Pushing #{APP_ENV} to #{APP}..."
    sh_with_clean_env "git push #{DEPLOY_GIT_URL}#{APP}.git #{APP_ENV}:master"

    puts "-----> Migrating..."
    sh_with_clean_env "heroku run rake db:migrate --app #{APP}"

    puts "-----> Seeding..."
    sh_with_clean_env "heroku run rake db:seed --app #{APP}"

    puts "-----> Restarting..."
    sh_with_clean_env "heroku restart --app #{APP}"
  end

  namespace :db do
    task :backup do
      unless ENV['SKIP_DB_BACKUP']
        # https://devcenter.heroku.com/articles/pgbackups
        puts "-----> Backup #{APP_ENV} database..."
        sh_with_clean_env "heroku pg:backups:capture --app #{APP}"
      end
    end

  end

  task :bundle_install do
    `bin/bundle install`
  end

  namespace :git do
    task :status_check do
      result = `git status`
      if result.include?('Untracked files:') ||
          result.include?('unmerged:') ||
          result.include?('modified:')
        puts result
        exit
      end
    end

    task 'master_branch_check' do
      cmd = []
      cmd << "git branch --color=never" # list branches avoiding color
                                        #   control characters
      cmd << "grep '^\*'"               # current branch is identified by '*'
      cmd << "cut -d' ' -f2"            # split by space, take branch name

      branch = `#{cmd.join('|')}`.chomp

      # Don't use == because git uses bash color escape sequences
      unless branch == 'master'
        puts "You are at branch <#{branch}>"
        puts "Integration deploy runs only from <master> branch," +
          " please merge <#{branch}> into <master> and" +
          " run integration proccess from there."

        exit
      end
    end

    task :pull do
      sh 'git pull --rebase'
    end

    task :push do
      sh 'git push'
    end

    task :promote_master_to_staging do
      sh "git checkout staging"
      sh 'git pull --rebase'
      sh "git rebase master"
      sh 'git push origin staging'
      sh "git checkout master"
    end

    task :promote_staging_to_production do
      sh "git checkout production"
      sh 'git pull --rebase'
      sh "git rebase staging"
      sh 'git push origin production'
      sh "git checkout master"
    end
  end
end
