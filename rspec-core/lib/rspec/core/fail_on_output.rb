require 'stringio'

module RSpec
  module Core
    # @private
    module FailOnOutput
      # @private
      class OutputWrittenError < StandardError; end

      MODES = [true, :stdout, :stderr]

      def self.run(procsy)
        mode = procsy.metadata[:fail_on_output]
        unless MODES.include?(mode)
          raise ArgumentError, "`:fail_on_output` must be `true`, `:stdout` or `:stderr`, " \
                               "but got #{mode.inspect}."
        end

        captured = {}
        captured['$stdout'] = StringIO.new unless mode == :stderr
        captured['$stderr'] = StringIO.new unless mode == :stdout

        original_stdout, original_stderr = $stdout, $stderr
        begin
          $stdout = captured['$stdout'] if captured['$stdout']
          $stderr = captured['$stderr'] if captured['$stderr']
          procsy.run
        ensure
          $stdout, $stderr = original_stdout, original_stderr
        end

        written = captured.reject { |_, io| io.string.empty? }
        return if written.empty?

        details = written.map { |name, io| "  #{name}: #{io.string.inspect}" }
        raise OutputWrittenError,
              "Expected the example not to write to #{written.keys.join(' or ')}, but it wrote:\n" \
              "#{details.join("\n")}",
              [procsy.example.location]
      end
    end
  end
end
