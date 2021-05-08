module Lobstersbot
  module PluggableConnection
    @@triggers = [
      # The default command handler.
      [
        0,
        /\A\.(?<command>[a-z]+)\s(?<message>.+)\z/i,
        lambda do |bot, channel, nick, match|
          bot.evaluate(:"on_#{match[:command]}", channel, nick, match[:message])
        end,
      ],
    ]

    def self.triggers
      @@triggers
    end

    def self.included(mod)
      mod.extend(ClassMethods)
    end

    module ClassMethods
      def add_trigger(priority, regex, handler)
        PluggableConnection.triggers << [priority, regex, handler]
      end
    end

    def respond(channel, nick, msg)
      privmsg("#{nick}: #{msg}", channel)
    end

    def did_start_up
      @memory = PStore.new(config_dir('memory.pstore'), true)

      # Sort the triggers by priority.
      @@triggers.sort! {|a, b| b[0] <=> a[0] }

      timer = Concurrent::TimerTask.new(execution_interval: 1) { evaluate(:frequently) }
      timer.execute
    end

    def channel_message(sender, channel, message)
      match = nil

      _, _, handler = @@triggers.find do |trigger|
        match = message.match(trigger[1])
        !match.nil?
      end
      return unless match

      handler.call(self, channel, sender[:nick], match)
    end

    def join_event(sender, channel)
      response_proc = ->(msg) { privmsg("#{sender[:nick]}: #{msg}", channel) }
      evaluate(:seen, sender[:nick], response_proc)
    end

    def evaluate(group, *args)
      matching = public_methods.select {|m| m.to_s.start_with?(group.to_s) }

      matching.each do |match|
        slice_name = match.to_s.sub("#{group}_", '').to_sym
        @memory.transaction do
          slice = @memory[slice_name] ||= {}
          self.send(match, slice, *args)
        end
      end
    end
  end
end
