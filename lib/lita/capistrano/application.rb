require 'net/ssh'
module Lita # :nodoc:
  module Capistrano # :nodoc:
    class Application

      attr_reader :name, :environment, :command
      def initialize(name:, command:, environment:)
        @name = name
        @command = command
        @environment = environment
      end

      def deploy(ssh:, bot:)
        bot.reply "Deploying application #{name} in #{environment}"
        Net::SSH.start(ssh[:server], ssh[:ssh_options].fetch(:user), ssh[:ssh_options]) do |connection|
          connection.open_channel do |ch|
            hash = match_data_to_hash(bot.match_data)
            cmd = command % hash
            Lita.logger.debug("Executing #{cmd} on #{ssh[:server]}")
            ch.exec cmd do |_ch, success|
              return bot.reply('could not execute command') unless success
              ch.on_data do |_c, data|
                Lita.logger.debug(data)
                bot.reply data
              end
              ch.on_extended_data do |_c, _type, data|
                Lita.logger.error(data)
                bot.reply data
              end
            end
          end.wait
        end
        bot.reply "Done deploying #{name} in #{environment}"
      end

      class <<self

        def find_by(name:, environment:)
          yaml = Lita.redis["capistrano:#{environment}:#{name}"]
          yaml && YAML.load(yaml)
        end

        def create(name:, command:, environment:)
          instance = new(name: name, command: command, environment: environment)
          Lita.redis["capistrano:#{environment}:#{name}"] = instance.to_yaml
        end

      end

      private

      def match_data_to_hash(match_data)
        Hash[match_data.names.zip(match_data.captures)].each_with_object({}) do |(k, v), memo|
          memo[k.to_sym] = v
        end
      end

    end
  end
end
