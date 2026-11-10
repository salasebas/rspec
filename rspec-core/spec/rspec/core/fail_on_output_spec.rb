RSpec.describe "Failing on output via `:fail_on_output` metadata" do
  let(:outer_stdout) { StringIO.new }
  let(:outer_stderr) { StringIO.new }

  def run_example(group_metadata={}, example_metadata={}, &block)
    ex = nil
    group = RSpec.describe("group", group_metadata) do
      ex = example("ex", example_metadata, &block)
    end

    original_stdout, original_stderr = $stdout, $stderr
    begin
      $stdout, $stderr = outer_stdout, outer_stderr
      group.run
      @streams_after_run = [$stdout, $stderr]
    ensure
      $stdout, $stderr = original_stdout, original_stderr
    end

    ex
  end

  it 'leaves output alone for examples without the metadata' do
    ex = run_example do
      puts "out"
      warn "err"
    end

    expect(ex.execution_result.status).to eq(:passed)
    expect(outer_stdout.string).to eq("out\n")
    expect(outer_stderr.string).to eq("err\n")
  end

  it 'fails an example tagged `fail_on_output: :stdout` that writes to $stdout, showing what was written' do
    ex = run_example(:fail_on_output => :stdout) { puts "stray debug" }

    expect(ex.execution_result.status).to eq(:failed)
    expect(ex.execution_result.exception.message).to eq(<<~MESSAGE.chomp)
      Expected the example not to write to $stdout, but it wrote:
        $stdout: "stray debug\\n"
    MESSAGE
    expect(ex.execution_result.exception.backtrace).to eq([ex.location])
    expect(outer_stdout.string).to eq("")
    expect(@streams_after_run).to eq([outer_stdout, outer_stderr])
  end

  it 'lets an example tagged `fail_on_output: :stdout` write to $stderr' do
    ex = run_example(:fail_on_output => :stdout) { warn "err" }

    expect(ex.execution_result.status).to eq(:passed)
    expect(outer_stderr.string).to eq("err\n")
  end

  it 'fails an example tagged `fail_on_output: :stderr` that writes to $stderr, and lets it write to $stdout' do
    ex = run_example(:fail_on_output => :stderr) do
      puts "out"
      warn "err"
    end

    expect(ex.execution_result.status).to eq(:failed)
    expect(ex.execution_result.exception.message).to eq(<<~MESSAGE.chomp)
      Expected the example not to write to $stderr, but it wrote:
        $stderr: "err\\n"
    MESSAGE
    expect(outer_stdout.string).to eq("out\n")
  end

  it 'reports both streams for an example tagged `fail_on_output: true`' do
    ex = run_example(:fail_on_output => true) do
      puts "out"
      warn "err"
    end

    expect(ex.execution_result.status).to eq(:failed)
    expect(ex.execution_result.exception.message).to eq(<<~MESSAGE.chomp)
      Expected the example not to write to $stdout or $stderr, but it wrote:
        $stdout: "out\\n"
        $stderr: "err\\n"
    MESSAGE
  end

  it 'passes a tagged example that writes nothing, and restores $stdout and $stderr' do
    ex = run_example(:fail_on_output => true) { 1 + 1 }

    expect(ex.execution_result.status).to eq(:passed)
    expect(@streams_after_run).to eq([outer_stdout, outer_stderr])
  end

  it 'can be turned off for one example in a tagged group with `fail_on_output: false`' do
    ex = run_example({ :fail_on_output => :stdout }, { :fail_on_output => false }) { puts "debugging" }

    expect(ex.execution_result.status).to eq(:passed)
    expect(outer_stdout.string).to eq("debugging\n")
  end

  it 'reports the output alongside a failure raised by the example' do
    ex = run_example(:fail_on_output => :stdout) do
      puts "out"
      raise "boom"
    end

    expect(ex.execution_result.exception.all_exceptions.map(&:message)).to match [
      "boom",
      /\AExpected the example not to write to \$stdout/
    ]
    expect(@streams_after_run).to eq([outer_stdout, outer_stderr])
  end

  it 'fails with a clear error for an unsupported value' do
    ex = run_example(:fail_on_output => :stdot) {}

    expect(ex.execution_result.exception).to be_an(ArgumentError).and have_attributes(
      :message => "`:fail_on_output` must be `true`, `:stdout` or `:stderr`, but got :stdot."
    )
  end
end
