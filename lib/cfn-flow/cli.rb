module CfnFlow
  class CLI < Thor

    def self.exit_on_failure?
      CfnFlow.exit_on_failure?
    end

    no_commands do
      def load_config
        defaults = { 'from' => '.' }
        file_config = begin
                        YAML.load_file(ENV['CFN_FLOW_CONFIG'] || './cfn-flow.yml')
                      rescue Errno::ENOENT
                        {}
                      end
        env_config = {
          'bucket'      => ENV['CFN_FLOW_BUCKET'],
          'to'          => ENV['CFN_FLOW_TO'],
          'from'        => ENV['CFN_FLOW_FROM'],
          'dev-name'    => ENV['CFN_FLOW_DEV_NAME'],
          'region'      => ENV['AWS_REGION']
        }.delete_if {|_,v| v.nil?}

        # Env vars override config file. Command args override env vars.
        self.options = defaults.merge(file_config).merge(env_config).merge(options)

        # Ensure region env var is set for AWS client
        ENV['AWS_REGION'] = options['region']

        # validate required options are present
        %w(region bucket to from).each do |arg|
          unless options[arg]
            raise Thor::RequiredArgumentMissingError.new("Missing required argument '#{arg}'")
          end
        end

        unless options['dev-name'] || options['release']
          raise Thor::RequiredArgumentMissingError.new("Missing either 'dev-name' or 'release' argument")
        end
      end

    end

    ##
    # Template methods

    desc 'validate TEMPLATE [...]', 'Validates templates'
    method_option :verbose, type: :boolean, desc: 'Verbose output', default: false
    def validate(*templates)

      if templates.empty?
        raise Thor::RequiredArgumentMissingError.new('You must specify a template to validate')
      end

      templates.map{|path| Template.new(path) }.each do |template|
        say "Validating #{template.local_path}... "
        template.validate!
        say 'valid.', :green
      end
    rescue Aws::CloudFormation::Errors::ValidationError => e
      raise Thor::Error.new("Invalid template. Message: #{e.message}")
    rescue CfnFlow::Template::Error => e
      raise Thor::Error.new("Error loading template. (#{e.class}) Message: #{e.message}")
    end

    desc 'publish TEMPLATE [...]', 'Validate & upload templates to the CFN_FLOW_DEV_NAME prefix'
    method_option 'dev-name', type: :string, desc: 'Personal development prefix'
    method_option :release,   type: :string, desc: 'Upload release', lazy_default: CfnFlow::Git.sha
    method_option :verbose,   type: :boolean, desc: 'Verbose output', default: false
    def publish(*templates)
      CfnFlow::Git.check_status if options['release']

      validate
      @templates.each do |t|
        say "Uploading #{t.from} to #{t.url}"
        t.upload!
      end

    end

    ##
    # Stack methods

    desc 'deploy ENVIRONMENT', 'Launch a stack'
    def deploy(environment)
      # TODO
      # Optionally invoke cleanup
    end

    desc :list, 'List running stacks'
    def list
      # TODO
    end

    desc 'show STACK', 'Show details about STACK'
    def show(stack)
      # TODO
    end

    desc 'events STACK', 'List events for  STACK'
    def events(stack)
      # TODO
    end


    desc 'cleanup', 'Shut down a stack'
    method_option :force, type: :boolean, default: false, desc: 'Shut down without confirmation'
    method_option :except, type: :string, desc: 'A list of stacks to omit from cleanup'
    def cleanup
      # TODO
    end










    private
    def verbose(msg)
      say msg if options['verbose']
    end

    def prefix
      # Add the release or dev name to the prefix
      parts = []
      parts << options['to']
      if options['release']
        parts += [ 'release',  options['release'] ]
      else
        parts += [ 'dev', options['dev-name'] ]
      end
      File.join(*parts)
    end
  end
end
