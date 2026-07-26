require "utils"
require 'minestrone/configuration/actions/file_transfer'

class ConfigurationActionsFileTransferTest < Test::Unit::TestCase
  class MockConfig
    include Minestrone::Configuration::Actions::FileTransfer
    attr_accessor :session, :dry_run
  end

  def setup
    @config = MockConfig.new
    @config.stubs(:logger).returns(stub_everything)
  end

  def test_put_should_delegate_to_upload
    @config.expects(:upload).with { |from, to, opts|
      from.string == "some data" && to == "test.txt" && opts == { :mode => 0777 } }
    @config.expects(:run).never
    @config.put("some data", "test.txt", :mode => 0777)
  end

  def test_get_should_delegate_to_download
    @config.expects(:download).with("testr.txt", "testl.txt", { :foo => "bar" })
    @config.get("testr.txt", "testl.txt", :foo => "bar")
  end

  def test_upload_should_delegate_to_transfer
    @config.expects(:transfer).with(:up, "testl.txt", "testr.txt", { :foo => "bar" })
    @config.upload("testl.txt", "testr.txt", :foo => "bar")
  end

  def test_upload_without_mode_should_not_try_to_chmod
    @config.expects(:transfer).with(:up, "testl.txt", "testr.txt", { :foo => "bar" })
    @config.expects(:run).never
    @config.upload("testl.txt", "testr.txt", :foo => "bar")
  end

  def test_upload_with_mode_should_try_to_chmod
    @config.expects(:transfer).with(:up, "testl.txt", "testr.txt", { :foo => "bar" })
    @config.expects(:run).with("chmod 775 testr.txt", {:foo => "bar"})
    @config.upload("testl.txt", "testr.txt", :mode => 0775, :foo => "bar")
  end

  def test_upload_with_symbolic_mode_should_try_to_chmod
    @config.expects(:transfer).with(:up, "testl.txt", "testr.txt", { :foo => "bar" })
    @config.expects(:run).with("chmod g+w testr.txt", {:foo => "bar"})
    @config.upload("testl.txt", "testr.txt", :mode => "g+w", :foo => "bar")
  end

  def test_upload_file_should_alias_upload
    @config.expects(:transfer).with(:up, "testl.txt", "testr.txt", { :foo => "bar" })
    @config.expects(:run).with("chmod 775 testr.txt", { :foo => "bar" })
    @config.upload_file("testl.txt", "testr.txt", :mode => 0775, :foo => "bar")
  end

  def test_download_should_delegate_to_transfer
    @config.expects(:transfer).with(:down, "testr.txt", "testl.txt", { :foo => "bar" })
    @config.download("testr.txt", "testl.txt", :foo => "bar")
  end

  def test_transfer_should_invoke_transfer_on_the_configured_server
    @config.session = 1
    @config.expects(:execute_on_server).yields
    Minestrone::Transfer.expects(:process).with(:up, "testl.txt", "testr.txt", 1, {:foo => "bar", :logger => @config.logger})
    @config.transfer(:up, "testl.txt", "testr.txt", :foo => "bar")
  end
end
