#
# Copyright(c) Anders Bengtsson 2003
#

require 'madeleine'

module Madeleine
  module Clock

    # Optimizes the logging of commands from a TimeActor.
    class ClockedSnapshotMadeleine < SnapshotMadeleine

      def initialize(directory_name, marshaller=nil, &new_system_block)
        if marshaller.nil?
          super(directory_name, &new_system_block)
        else
          super(directory_name, marshaller, &new_system_block)
        end
      end

      private

      def create_logger(directory_name, log_factory)
        TimeOptimizingLogger.new(directory_name, log_factory)
      end
    end

    # Let your system extend this module if you need to access the
    # machine time. Used together with a TimeActor that keeps
    # the clock current.
    module ClockedSystem

      # Returns this system's Clock.
      def clock
        unless defined? @clock
          @clock = Clock.new
        end
        @clock
      end
    end

    # Sends clock ticks to update a ClockedSystem, so that time can be
    # dealt with in a deterministic way.
    class TimeActor

      # Create and launch a new TimeActor
      #
      # * <tt>madeleine</tt> - The SnapshotMadeleine instance to work on.
      # * <tt>delay</tt> - Delay between ticks in seconds (Optional).
      def self.launch(madeleine, delay=0.1)
        result = new(madeleine, delay)
        result
      end

      # Stops the TimeActor.
      def destroy
        @is_destroyed = true
        @thread.wakeup
        @thread.join
      end

      private_class_method :new

      private

      def initialize(madeleine, delay) #:nodoc:
        @madeleine = madeleine
        @is_destroyed = false
        send_tick
        @thread = Thread.new {
          until @is_destroyed
            sleep(delay)
            send_tick
          end
        }
      end

      def send_tick
        @madeleine.execute_command(Tick.new(Time.now))
      end
    end

    # Keeps track of time in a ClockedSystem.
    class Clock
      # Returns the system's time as a Ruby <tt>Time</tt>.
      attr_reader :time

      def initialize
        @time = Time.at(0)
      end

      def forward_to(newTime)
        if newTime < @time
          raise "Can't decrease clock's time."
        end
        @time = newTime
      end
    end

    #
    # Internal classes below
    #

    # Deprecated. Merged into default implementation.
    TimeOptimizingLogger = Logger


    class Tick #:nodoc:

      def initialize(time)
        @time = time
      end

      def execute(system)
        system.clock.forward_to(@time)
      end
    end
  end
end

ClockedSnapshotMadeleine = Madeleine::Clock::ClockedSnapshotMadeleine
