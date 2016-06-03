module Lita
  module Handlers
    class Capistrano < Handler

      config :ssh, type: Hash, required: true

      route(/^(?<application>.+) is deployed in (?<environment>[^\s]+) using "(?<command>.*)("|”) command$/,
            :add_application, command: :true, help:
            { 'APP is deployed in ENVIRONMENT using "SHELL" command' => 'example.com is deployed in staging using "bundle exec cap staging deploy" command' })

      route(/^deploy (?<application>.+) (on|in) (?<environment>.*)$/,
            :deploy_application, command: :true, help:
            { 'deploy NAME on ENVIRONMENT' => 'deploy example.com in staging' })

      def deploy_application(response)
        name = response.match_data[:application]
        environment = response.match_data[:environment]
        application = find_application(name: name, environment: environment)
        return response.reply "#{name} not found" unless application
        application.deploy(bot: response, ssh: config.ssh)
      end

      def add_application(response)
        name = response.match_data[:application]
        command = response.match_data[:command]
        environment = response.match_data[:environment]
        application = find_application(name: name, environment: environment)
        return response.reply "application #{name} already exists" if application

        Lita::Capistrano::Application.create(
          name: name,
          command: command,
          environment: environment
        )
        response.reply "Ok now I known how to deploy #{name} in #{environment}"
      end

      private

      def find_application(name:, environment:)
        Lita::Capistrano::Application.find_by(name: name, environment: environment)
      end

      Lita.register_handler(self)

    end
  end
end
