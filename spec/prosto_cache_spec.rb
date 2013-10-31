require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Model with prosto cache mixed in" do
  let(:model_class) {
    Class.new {
      def self.after_save; end
      include ProstoCache
    }
  }

  it "should have cache method" do
    model_class.cache.should_not be_nil
    model_class.cache.should be_an_instance_of(ProstoCache::ProstoModelCache)
  end

  describe '.cache' do
    it "should not load cache if it was never accessed" do
      model_class.cache.should_not_receive(:query_cache_signature)
      model_class.should_not_receive(:all)

      model_class.cache.should_not be_nil
    end
  end
end

describe ProstoCache::ProstoModelCache do
  context "with single key access" do
    let(:model_class) {
      Class.new {
        def self.after_save; end

        include ProstoCache

        attr_accessor :name
        def initialize(name)
          self.name = name
        end
      }.tap { |model_class|
        model_class.cache.stub(:query_cache_signature).once.and_return(:something)
        model_class.stub(:all).once.and_return(%w(foo bar).map { |n| model_class.new(n) })
      }
    }

    describe "#keys" do
      it "should return all keys from the cache" do
        model_class.cache.keys.should == [:bar, :foo]
      end
    end

    describe "#values" do
      it "should return all values from the cache" do
        values = model_class.cache.values
        values.should have(2).instances
        # values.map(&:name).should == %w(foo bar)
        values.map(&:name).should include('foo')
        values.map(&:name).should include('bar')
      end

      it "should sort values by accessor key" do
        values = model_class.cache.values
        values.map(&:name).should == %w(bar foo)
      end

      context 'when sort_keys are provided' do
        let(:model_class) {
          Class.new {
            def self.after_save; end

            include ProstoCache

            cache_sort_keys(:reversed_name)

            attr_accessor :name
            def initialize(name)
              self.name = name
            end

            def reversed_name
              name.reverse
            end
          }.tap { |model_class|
            model_class.cache.stub(:query_cache_signature).once.and_return(:something)
            model_class.stub(:all).once.and_return(%w(foo bar).map { |n| model_class.new(n) })
          }
        }

        it "should sort values by sort key" do
          values = model_class.cache.values
          values.map(&:name).should == %w(foo bar)
        end
      end
    end

    describe "#[]" do
      it "should load cache when it is accessed" do
        model_class.should_receive(:all).once.and_return(%w(foo bar).map { |n| model_class.new(n) })

        model_class.cache[:foo]
      end

      context 'when key is symbol' do
        it "should raise an error for key that was not found" do
          expect { model_class.cache[:nondef] }.to raise_error ProstoCache::BadCacheKeyError
        end

        it "should return proper object for key that was found" do
          model_class.cache[:foo].should_not be_nil
          model_class.cache[:foo].name.should == 'foo'
        end
      end

      context 'when key is string' do
        it "should return nil for key that was not found" do
          model_class.cache['nondef'].should be_nil
        end

        it "should return proper object for key that was found" do
          model_class.cache['foo'].should_not be_nil
          model_class.cache['foo'].name.should == 'foo'
        end
      end
    end
  end

  context "with composite key access" do
    let(:model_class) {
      Class.new {
        def self.after_save; end

        include ProstoCache

        cache_accessor_keys %w(key1 key2)

        attr_accessor :name, :key1, :key2
        def initialize(name, key1, key2)
          self.name = name
          self.key1 = key1
          self.key2 = key2
        end
      }.tap { |model_class|
        model_class.cache.stub(:query_cache_signature).once.and_return(:foo)
        model_class.stub(:all).once.and_return(%w(foo bar).map { |n| model_class.new(n, n + '1', n + '2') })
      }
    }

    describe "#keys" do
      it "should return all keys from the cache as array of arrays" do
        model_class.cache.keys.should == [[:bar1, :bar2], [:foo1, :foo2]]
      end
    end

    describe "#values" do
      it "should return all values from the cache" do
        values = model_class.cache.values
        values.should have(2).instances
        # values.map(&:name).should == %w(foo bar)
        values.map(&:name).should include('foo')
        values.map(&:name).should include('bar')
      end

      it "should sort values by accessor keys" do
        values = model_class.cache.values
        values.map(&:name).should == %w(bar foo)
      end

      context 'when sort_keys are provided' do
        let(:model_class) {
          Class.new {
            def self.after_save; end

            include ProstoCache

            cache_accessor_keys %w(key1 key2)
            cache_sort_keys(%w(reversed_name key1 key2))

            attr_accessor :name, :key1, :key2
            def initialize(name, key1, key2)
              self.name = name
              self.key1 = key1
              self.key2 = key2
            end

            def reversed_name
              name.reverse
            end
          }.tap { |model_class|
            model_class.cache.stub(:query_cache_signature).once.and_return(:foo)
            model_class.stub(:all).once.and_return(%w(foo bar).map { |n| model_class.new(n, n + '1', n + '2') })
          }
        }

        it "should sort values by sort keys" do
          values = model_class.cache.values
          values.map(&:name).should == %w(foo bar)
        end
      end
    end

    describe "#[]" do
      it "should raise an error when not enough keys provided" do
        expect { model_class.cache[:nondef] }.to raise_error ProstoCache::BadCacheKeyError
        expect { model_class.cache[:foo1] }.to raise_error ProstoCache::BadCacheKeyError
        expect { model_class.cache['nondef'] }.to raise_error ProstoCache::BadCacheKeyError
        expect { model_class.cache['foo1'] }.to raise_error ProstoCache::BadCacheKeyError
      end

      it "should raise an error when too many keys provided" do
        expect { model_class.cache[:nondef1, :nondef2, :nondef3] }.to raise_error ProstoCache::BadCacheKeyError
        expect { model_class.cache[:foo1, :foo2, :nondef] }.to raise_error ProstoCache::BadCacheKeyError
        expect { model_class.cache['nondef1', 'nondef2', 'nondef3'] }.to raise_error ProstoCache::BadCacheKeyError
        expect { model_class.cache['foo1', 'foo2', 'nondef'] }.to raise_error ProstoCache::BadCacheKeyError
      end

      context 'when last key is symbol' do
        it "should raise an error for first key that was not found" do
          expect { model_class.cache[:undef, :foo2] }.to raise_error ProstoCache::BadCacheKeyError
          expect { model_class.cache['undef', :foo2] }.to raise_error ProstoCache::BadCacheKeyError
        end

        it "should raise an error for last key that was not found" do
          expect { model_class.cache[:foo1, :nondef] }.to raise_error ProstoCache::BadCacheKeyError
          expect { model_class.cache['foo1', :nondef] }.to raise_error ProstoCache::BadCacheKeyError
        end

        it "should return proper object for key that was found" do
          model_class.cache[:foo1, :foo2].should_not be_nil
          model_class.cache[:foo1, :foo2].name.should == 'foo'
        end
      end

      context 'when last key is string' do
        it "should return nil for first level key that was not found" do
          model_class.cache['nondef', 'foo2'].should be_nil
          model_class.cache[:nondef, 'foo2'].should be_nil
        end

        it "should return nil for second level key that was not found" do
          model_class.cache['foo1', 'nondef'].should be_nil
          model_class.cache[:foo1, 'nondef'].should be_nil
        end

        it "should return proper object for key that was found" do
          model_class.cache['foo1', 'foo2'].should_not be_nil
          model_class.cache['foo1', 'foo2'].name.should == 'foo'
        end
      end
    end
  end
end
