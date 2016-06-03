module Lita
  module Handlers
    class Capistrano < Handler

      config :ssh, type: Hash, required: true

      route(/^deploy (?<application>.+) (on|in) (?<environment>.*)$/,
            :deploy_application, command: :true, help:
            { 'deploy NAME on ENVIRONMENT' => 'deploy example.com on staging' })

      route(/^(?<action>allow|disallow) (?<handle>.+) to deploy (?<application>.+) (on|in) (?<environment>.*)$/,
            :manage_deployment, command: :true, help:
            { '(dis)allow HANDLE to deploy APP on ENVIRONMENT' => 'allow @chuck to deploy example.com on staging' })

      route(/^who can deploy (?<application>.+)( (on|in) (?<environment>.+))?\s?\?$/,
            :show_members, command: :true, help:
            { 'who can deploy APP( on ENVIRONMENT)?' => 'show who is alloed to deploy' })

      route(/^what can be deployed\s?\?$/,
            :show_applications, command: :true, help:
            { 'what can be deployed?' => 'shows the applications that can be deployed' })

      def deploy_application(response)
        app = Lita::Capistrano::Application.new(
          name: response.match_data[:application],
          environment: response.match_data[:environment],
          ssh: config.ssh
        )

        if deploy_allowed?(app.name, app.environment, response.user)
          app.deploy(response)
        else
          response.reply("You're not allowed to deploy #{app.name} on #{app.environment}")
        end
      rescue => e
        exception_handler(e, response)
        raise
      end

      def manage_deployment(response)
        return unless Lita.config.robot.admins.include?(response.user.id)
        text = response.match_data[:handle]
        text = text[1..-1] if text.start_with?("@")
        user = Lita::User.fuzzy_find(text)
        environment = response.match_data[:environment]
        app = response.match_data[:application]
        return response.reply("Unable to find a matching user for #{response.match_data[:handle]}") unless user
        Lita.logger.debug user.inspect
        if response.match_data[:action] == "allow"
          Lita.redis.sadd("capistrano:#{app}:#{environment}:members", user.id)
          response.reply("#{user.name} can deploy #{app} on #{environment}")
        else
          Lita.redis.srem("capistrano:#{app}:#{environment}:members", user.id)
          response.reply("#{user.name} can't deploy #{app} on #{environment} anymore")
        end
      end

      def show_members(response)
        environments = [response.match_data[:environment]].compact
        app = response.match_data[:application]
        Lita.logger.debug environments.inspect
        environments = Lita.redis.keys("capistrano:#{app}:*:members").map do |key|
          key.split(":")[-2]
        end.uniq if environments.empty?

        environments.each do |environment|
          names = Lita.redis.smembers("capistrano:#{app}:#{environment}:members").map do |id|
            Lita::User.find_by_id(id)
          end.map(&:mention_name).join(", ")

          response.reply "#{app} can be deployed by #{names} on #{environment}"
        end
      end

      def show_applications(response)
        apps = Lita.redis.keys("capistrano:*:*:members").each_with_object({}) do |key, app|
          parts = key.split(":")
          (app[parts[-3]] ||= Set.new) << parts[-2]
        end

        if apps.empty?
          response.reply "There is nothing that can be deployed"
        else
          apps.each do |app, environments|
            response.reply "#{app} can be deployed on #{environments.to_a.join(", ")}"
          end
        end
      end

      private

      def deploy_allowed?(app, environment, user)
        Lita.redis.sismember("capistrano:#{app}:#{environment}:members", user.id)
      end

      def exception_handler(exception, response)
        relevant_lines = filter_backtrace(exception.backtrace)
        response.reply "I've encounterd #{exception.message} error at ```#{relevant_lines.join("\n")}```"
      end

      def filter_backtrace(lines)
        lines.select do |line|
          line.start_with? File.expand_path("../../../../", __FILE__)
        end
      end

      Lita.register_handler(self)

    end
  end
end
