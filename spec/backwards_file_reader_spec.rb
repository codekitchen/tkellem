require 'spec_helper'

describe BackwardsFileReader do
  let :testfile do
    Tempfile.new("tkellem-test").tap do |tf|
      tf.write <<-LINES
line1
line2
line3
LINES
      tf.rewind
    end
  end

  describe '.scan' do
    it "should read all lines" do
      results = mock('lines')
      results.expects(:got).with("line3\n")
      results.expects(:got).with("line2\n")
      results.expects(:got).with("line1\n")

      BackwardsFileReader.scan(testfile) { |line| results.got(line); true }
      testfile.pos.should == 0
    end

    it "should abort if the block returns false" do
      results = mock('lines')
      results.expects(:got).with("line3\n")
      results.expects(:got).with("line2\n")
      BackwardsFileReader.scan(testfile) do |line|
        results.got(line)
        line != "line2\n"
      end
      testfile.pos.should == 6
    end
  end

  describe "#readline" do
    it "should read correctly with a buffer size smaller than one line" do
      reader = BackwardsFileReader.new(testfile, 2)
      reader.readline.should == "line3\n"
      reader.readline.should == "line2\n"
      reader.readline.should == "line1\n"
      reader.readline.should == nil
    end

    it "should read correctly with a buffer size larger than one line" do
      reader = BackwardsFileReader.new(testfile, 6)
      reader.readline.should == "line3\n"
      reader.readline.should == "line2\n"
      reader.readline.should == "line1\n"
      reader.readline.should == nil
    end
  end

  describe "#sync" do
    it "should reset the stream position to the current line" do
      reader = BackwardsFileReader.new(testfile)
      reader.readline
      reader.sync.should == testfile
      testfile.pos.should == testfile.size - 6

      reader = BackwardsFileReader.new(testfile)
      reader.readline
      reader.readline
      reader.sync.should == testfile
      testfile.pos.should == testfile.size - 12
    end

    it "should reset correctly with a buffer size smaller than one line" do
      reader = BackwardsFileReader.new(testfile, 2)
      reader.readline
      reader.sync.should == testfile
      testfile.pos.should == testfile.size - 6

      reader = BackwardsFileReader.new(testfile, 2)
      reader.readline
      reader.readline
      reader.sync.should == testfile
      testfile.pos.should == testfile.size - 12
    end

    it "should reset correctly with a buffer size larger than one line" do
      reader = BackwardsFileReader.new(testfile, 7)
      reader.readline
      reader.sync.should == testfile
      testfile.pos.should == testfile.size - 6

      reader = BackwardsFileReader.new(testfile, 7)
      reader.readline
      reader.readline
      reader.sync.should == testfile
      testfile.pos.should == testfile.size - 12
    end
  end

  it "should support resuming" do
    reader = BackwardsFileReader.new(testfile, 2)
    reader.readline.should == "line3\n"
    reader.sync
    testfile.pos.should == testfile.size - 6
    reader.readline.should == "line2\n"
    reader.sync
    testfile.pos.should == testfile.size - 12
    reader.readline.should == "line1\n"
    reader.sync
    testfile.pos.should == 0
  end
end
