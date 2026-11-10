Feature: Failing examples that write output

  Tag an example or group with `:fail_on_output` metadata to make an example fail when it writes to `$stdout` or `$stderr`. This keeps stray `puts` and warnings out of your test output. The failure says which stream was written to and shows what was written.

  The value picks the streams:

    * `fail_on_output: :stdout` fails on writes to `$stdout`.
    * `fail_on_output: :stderr` fails on writes to `$stderr`.
    * `fail_on_output: true` fails on writes to either.

  Use `config.define_derived_metadata` to apply it to every example, and `fail_on_output: false` to turn it off for an example or group, for instance while debugging.

  RSpec replaces `$stdout` and `$stderr` while the example and its hooks run, so writes made directly to `STDOUT` or `STDERR`, or by subprocesses or C extensions, are not detected.

  Scenario: Fail examples in a tagged group that write to `$stdout`
    Given a file named "spec/widget_spec.rb" with:
      """ruby
      RSpec.describe "Widget", :fail_on_output => :stdout do
        it "prints a debug line" do
          print "debug: building widget"
        end

        it "warns" do
          warn "careful"
        end
      end
      """
    When I run `rspec spec/widget_spec.rb`
    Then it should fail with "2 examples, 1 failure"
    And the output should contain:
      """
           Failure/Error:
             it "prints a debug line" do
               print "debug: building widget"
             end

             Expected the example not to write to $stdout, but it wrote:
               $stdout: "debug: building widget"
      """

  Scenario: Enable it for every example, and turn it off for one
    Given a file named "spec/spec_helper.rb" with:
      """ruby
      RSpec.configure do |c|
        c.define_derived_metadata do |meta|
          meta[:fail_on_output] = true unless meta.key?(:fail_on_output)
        end
      end
      """
    And a file named "spec/widget_spec.rb" with:
      """ruby
      require 'spec_helper'

      RSpec.describe "Widget" do
        it "warns" do
          $stderr.print "careful"
        end

        it "prints while debugging", :fail_on_output => false do
          puts "debugging"
        end
      end
      """
    When I run `rspec spec/widget_spec.rb`
    Then it should fail with "2 examples, 1 failure"
    And the output should contain:
      """
             Expected the example not to write to $stderr, but it wrote:
               $stderr: "careful"
      """
    And the output should contain "debugging"
