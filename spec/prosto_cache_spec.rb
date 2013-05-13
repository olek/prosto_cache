require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "ProstoCache" do
  before do
    Object.send(:remove_const, 'Foo') if Object.const_defined? 'Foo'

    class Foo; end
    Foo.stub(:after_save)
  end

  describe '#cache' do
    before do
      class Foo
        include ProstoCache
      end
    end

    it "should add a cache method" do
      Foo.cache.should_not be_nil
      Foo.cache.should be_an_instance_of(ProstoCache::ProstoModelCache)
    end

    it "should not load cache if it was never accessed" do
      Foo.cache.should_not_receive(:query_cache_signature)
      Foo.should_not_receive(:all)

      Foo.cache.should_not be_nil
    end
  end

  context "[] method with single key access" do
    before do
      class Foo
        include ProstoCache

        attr_accessor :name
        def initialize(name)
          self.name = name
        end
      end

      Foo.cache.stub(:query_cache_signature).once.and_return(:foo)
      Foo.stub(:all).once.and_return(%w(foo bar).map { |n| Foo.new(n) })
    end

    it "should load cache when it is accessed" do
      Foo.should_receive(:all).once.and_return(%w(foo bar).map { |n| Foo.new(n) })

      Foo.cache[:foo]
    end

    context 'when key is symbol' do
      it "should raise an error for key that was not found" do
        expect { Foo.cache[:nondef] }.to raise_error ProstoCache::BadCacheKeyError
      end

      it "should return proper object for key that was found" do
        Foo.cache[:foo].should_not be_nil
        Foo.cache[:foo].name.should == 'foo'
      end
    end

    context 'when key is string' do
      it "should return nil for key that was not found" do
        Foo.cache['nondef'].should be_nil
      end

      it "should return proper object for key that was found" do
        Foo.cache['foo'].should_not be_nil
        Foo.cache['foo'].name.should == 'foo'
      end
    end
  end

  context "[] method with composite key access" do
    before do
      class Foo
        include ProstoCache
        cache_accessor_keys %w(key1 key2)

        attr_accessor :name, :key1, :key2
        def initialize(name, key1, key2)
          self.name = name
          self.key1 = key1
          self.key2 = key2
        end
      end

      Foo.cache.stub(:query_cache_signature).once.and_return(:foo)
      Foo.stub(:all).once.and_return(%w(foo bar).map { |n| Foo.new(n, n + '1', n + '2') })
    end

    it "should raise an error when not enough keys provided" do
      expect { Foo.cache[:nondef] }.to raise_error ProstoCache::BadCacheKeyError
      expect { Foo.cache[:foo1] }.to raise_error ProstoCache::BadCacheKeyError
      expect { Foo.cache['nondef'] }.to raise_error ProstoCache::BadCacheKeyError
      expect { Foo.cache['foo1'] }.to raise_error ProstoCache::BadCacheKeyError
    end

    it "should raise an error when too many keys provided" do
      expect { Foo.cache[:nondef1, :nondef2, :nondef3] }.to raise_error ProstoCache::BadCacheKeyError
      expect { Foo.cache[:foo1, :foo2, :nondef] }.to raise_error ProstoCache::BadCacheKeyError
      expect { Foo.cache['nondef1', 'nondef2', 'nondef3'] }.to raise_error ProstoCache::BadCacheKeyError
      expect { Foo.cache['foo1', 'foo2', 'nondef'] }.to raise_error ProstoCache::BadCacheKeyError
    end

    context 'when last key is symbol' do
      it "should raise an error for first key that was not found" do
        expect { Foo.cache[:undef, :foo2] }.to raise_error ProstoCache::BadCacheKeyError
        expect { Foo.cache['undef', :foo2] }.to raise_error ProstoCache::BadCacheKeyError
      end

      it "should raise an error for last key that was not found" do
        expect { Foo.cache[:foo1, :nondef] }.to raise_error ProstoCache::BadCacheKeyError
        expect { Foo.cache['foo1', :nondef] }.to raise_error ProstoCache::BadCacheKeyError
      end

      it "should return proper object for key that was found" do
        Foo.cache[:foo1, :foo2].should_not be_nil
        Foo.cache[:foo1, :foo2].name.should == 'foo'
      end
    end

    context 'when last key is string' do
      it "should return nil for first level key that was not found" do
        Foo.cache['nondef', 'foo2'].should be_nil
        Foo.cache[:nondef, 'foo2'].should be_nil
      end

      it "should return nil for second level key that was not found" do
        Foo.cache['foo1', 'nondef'].should be_nil
        Foo.cache[:foo1, 'nondef'].should be_nil
      end

      it "should return proper object for key that was found" do
        Foo.cache['foo1', 'foo2'].should_not be_nil
        Foo.cache['foo1', 'foo2'].name.should == 'foo'
      end
    end
  end
end
