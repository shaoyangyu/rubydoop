# encoding: utf-8

$LOAD_PATH << File.expand_path('..', __FILE__)


require 'java'


module Hadoop
  module Io
    include_package 'org.apache.hadoop.io'
  end

  module Mapred
    include_package 'org.apache.hadoop.mapred'
  end

  module Fs
    include_package 'org.apache.hadoop.fs'
  end
end

module Rudoop
  class ConfigureContext
    def initialize(runner)
      @runner = runner
    end

    def job(name, &block)
      job_conf = @runner.create_job_conf
      job_conf.setJobName(name)
      job_conf_ctx = JobConfContext.new(job_conf)
      job_conf_ctx.instance_exec(&block)
      @runner.add_job(job_conf)
    end
  end

  class JobConfContext
    def initialize(conf)
      @conf = conf
    end

    def self.class_setter(dsl_name)
      define_method(dsl_name) do |cls|
        @conf.send("set_#{dsl_name}_class", cls.java_class)
      end
    end

    def input(paths, options={})
      paths = paths.join(',') if paths.is_a?(Enumerable)
      format = options[:format] || Hadoop::Mapred::FileInputFormat
      format.set_input_paths(@conf, paths)
    end

    def output(dir, options={})
      format = options[:format] || Hadoop::Mapred::FileOutputFormat
      format.set_output_path(@conf, Hadoop::Fs::Path.new(dir))
    end

    def mapper(cls)
      @conf.set("rudoop.mapper", cls.name)
    end

    def reducer(cls)
      @conf.set("rudoop.reducer", cls.name)
    end

    def combiner(cls)
      @conf.set("rudoop.combiner", cls.name)
    end

    class_setter :map_output_key
    class_setter :map_output_value
    class_setter :output_key
    class_setter :output_value
  end

  module ConfigurationDsl
    def configure(&block)
      if $rudoop_runner
        arguments = $rudoop_arguments.to_a
        configure_ctx = ConfigureContext.new($rudoop_runner)
        configure_ctx.instance_exec(*arguments, &block)
      end
    end
  end

  class Configurator
    java_import 'java.util.LinkedList'

    attr_reader :jobs

    def initialize(*args)
      @configuration, @example_class, @java_mapper_class, @java_reducer_class, @java_combiner_class = args
      @jobs = LinkedList.new
    end

    def create_job_conf
      job_conf = Hadoop::Mapred::JobConf.new(@configuration, @example_class)
      job_conf.set_mapper_class(@java_mapper_class)
      job_conf.set_reducer_class(@java_reducer_class)
      job_conf
    end

    def add_job(job_conf)
      if job_conf.get('rudoop.combiner')
        job_conf.set_combiner_class(@java_combiner_class)
      end
      @jobs.add(job_conf)
    end
  end

  def self.create_mapper(conf)
    create_instance(conf.get('rudoop.mapper'))
  end

  def self.create_reducer(conf)
    create_instance(conf.get('rudoop.reducer'))
  end

  def self.create_combiner(conf)
    create_instance(conf.get('rudoop.combiner'))
  end

  def self.create_instance(const_path)
    cls = const_path.split('::').reduce(Object) { |host, name| host.const_get(name) }
    cls.new
  end
end