require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ProstoCache" do
  before do
    Object.send(:remove_const, 'Foo') if Object.const_defined? 'Foo'

    class Foo; end
    Foo.should_receive(:after_save)
    class Foo
      include ProstoCache
    end
  end

  it "should be a mix-in" do
  end

  it "should add a cache method" do
    Foo.cache.should_not be_nil
    Foo.cache.should be_an_instance_of(ProstoCache::ProstoModelCache)
  end

  it "should not load cache if it was never accessed" do
    Foo.cache.should_not be_nil
    Foo.cache.should_not_receive(:query_cache_signature)
    Foo.should_not_receive(:all)
  end

  context "[] method with single key access" do
    before do
      Object.send(:remove_const, 'Foo') if Object.const_defined? 'Foo'

      class Foo
        attr_accessor :name
        def initialize(name)
          self.name = name
        end
      end

      Foo.should_receive(:after_save)

      class Foo
        include ProstoCache
      end

      Foo.cache.should_not be_nil
      Foo.cache.should_receive(:query_cache_signature).once.and_return(:foo)
      Foo.should_receive(:all).once.and_return(%w(foo bar).map { |n| Foo.new(n) })
    end

    it "should load cache when it is accessed" do
      Foo.cache[:nondef]
    end

    it "should return nil for key that was not found" do
      Foo.cache[:nondef].should be_nil
    end

    it "should return proper object for key that was found" do
      Foo.cache[:foo].should_not be_nil
      Foo.cache[:foo].name.should == 'foo'
      Foo.cache[:bar].name.should == 'bar'
    end
  end

  context "[] method with composite key access" do
    before do
      Object.send(:remove_const, 'Foo') if Object.const_defined? 'Foo'

      class Foo
        attr_accessor :key1, :key2, :name
        def initialize(name, key1, key2)
          self.name = name
          self.key1 = key1
          self.key2 = key2
        end
      end

      Foo.should_receive(:after_save)

      class Foo
        include ProstoCache
        cache_accessor_keys %w(key1 key2)
      end

      Foo.cache.should_not be_nil
      Foo.cache.should_receive(:query_cache_signature).once.and_return(:foo)
      Foo.should_receive(:all).once.and_return(%w(foo bar).map { |n| Foo.new(n, n + '1', n + '2') })
    end

    it "should return nil for first level key that was not found" do
      Foo.cache[:nondef].should be_nil
    end

    it "should return nil for second level key that was not found" do
      Foo.cache[:foo1][:nondef].should be_nil
    end

    it "should return nil for safe access method when first level key was not found" do
      Foo.cache[[:nodef, :foo2]].should be_nil
    end

    it "should return proper object for key that was found, using unsafe access method" do
      Foo.cache[:foo1][:foo2].should_not be_nil
      Foo.cache[:foo1][:foo2].name.should == 'foo'
      Foo.cache[:bar1][:bar2].name.should == 'bar'
    end

    it "should return proper object for key that was found, using safe access method" do
      Foo.cache[[:foo1, :foo2]].should_not be_nil
      Foo.cache[[:foo1, :foo2]].name.should == 'foo'
      Foo.cache[[:bar1, :bar2]].name.should == 'bar'
    end

    it "should fail with exception for the unsafe access method when first level key that was not found" do
      lambda {
        Foo.cache[:nondef][:foo2]
      }.should raise_error
    end
  end
end
