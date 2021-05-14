# Objetivo

Este projeto implementa a visão que a nossa equipe acredita ser a melhor forma de trabalhar com controle de versão e deploy do projeto.

Cada ambiente está ligado diretamente a um branch. No nosso caso, temos 3(três) branchs principais:

 * master: é onde fazemos o desenvolvimento das histórias. Não pode ter impedimentos por conta de subidas semanais que fazemos.
 * staging: é o ambiente de testes interno. Sempre que compartilhamos o código, fazemos deploy para esse ambiente.
 * production: é o ambiente usado pelos clientes. Ele é construido a partir do ambiente staging.

# Passos da integração

0. Verifica se tem alguém integrando e bloqueia, caso tenha.
1. Só executa se não tiver nada para ser commitado.
2. Limpa a pasta de log e temp, do projeto.
3. git pull --rebase, para não criar um commit de merge. Consultamos o histórico, os commits de merge atrapalham ;)
4. Atualizar novas dependências, caso tenha sido adicionada: bundle install
5. Limpa o ambiente local, para verificar as mirations: rake db:drop db:create db:migrate db:seed db:test:prepare
6. Roda os testes: rake test
7. Garante que está na master, só fazemos integração por ela
8. Garante que a sua branch staging está atualizada e faz rebase da master:
      git checkout staging"
      git pull --rebase
      git rebase master
      git push origin staging
      git checkout master
9. Compartilha o código: git push
10. Adiciona uma variável no heroku para informar que você está fazendo deploy
11. Manda a branch staging para o projeto de staging no heroku: git push git@heroku.com:#{APP}.git staging:master
12. Roda as migrações no ambiente de staging: heroku run rake db:migrate --app #{APP
13. Roda o seed: heroku run rake db:seed --app #{APP}
14. Reinicia o ambiente de staging: heroku restart --app #{APP}
15. Remove a variável do heroku que informar que você estava fazendo deploy

# Como instalar no projeto

1. Cria o projeto
  1. Cria o projeto local
  1. git init
  1. git commit
  1. Cria o projeto no github(ou qualquer outro) e define ele como origin
  1. Define o origin como upstream da master:  <code>git push origin master --set-upstream </code>
  1. Cria dois projetos no Heroku, um para cada ambiente
  1. um com o sufixo -staging
  1. um com o sufixo -production
1. Adiciona a gem em <code>gem 'integrate', git: 'git@github.com:Easyfood/integrate.git'</code>
1. Criar a branch staging a partir da master: <code>git checkout staging</code>
1. Define o origin como upstream desse branch: <code>git push origin staging --set-upstream </code>
1. Criar a branch production a partir da staging: <code>git checkout production</code>
1. Define o origin como upstream desse branch: <code>git push origin production --set-upstream </code>
1. Caso precise usar um nome diferente no Heroku, adicione uma task no Rakefile do seu projeto:
```rake
task :force_different_name_for_heroku_project do
  ENV['PROJECT'] = 'pre-nutrebem'
  ENV['DEPLOY_GIT_URL'] = 'https://git.heroku.com/'
end

Rails.application.load_tasks # Se for um projeto Rails

Rake::Task['integration:environment'].enhance [:force_different_name_for_heroku_project]
```
