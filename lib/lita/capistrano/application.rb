require 'net/ssh'
module Lita # :nodoc:
  module Capistrano # :nodoc:
    class Application

      attr_reader :name, :environment, :ssh
      def initialize(name:, environment:, ssh: )
        @name = name
        @ssh = ssh
        @environment = environment
      end

      def deploy(bot)
        bot.reply "Deploying application #{name} on #{environment}"
        Net::SSH.start(ssh[:server], ssh[:user], ssh[:ssh_options]) do |connection|
          connection.open_channel do |ch|
            ch.exec "#{name} #{environment}" do |_ch, success|
              return bot.reply('could not execute command') unless success
              ch.on_data do |_c, data|
                Lita.logger.debug(data)
                bot.reply data.force_encoding("utf-8")
              end
              ch.on_extended_data do |_c, _type, data|
                Lita.logger.error(data)
                bot.reply data.force_encoding("utf-8")
              end
            end
          end.wait
        end
        bot.reply "Finished deploying #{name} on #{environment}"
      end

    end
  end
end
