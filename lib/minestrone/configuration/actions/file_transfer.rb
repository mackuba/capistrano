# frozen_string_literal: true

require 'minestrone/transfer'

module Minestrone
  class Configuration
    module Actions
      module FileTransfer

        # Store the given data at the given location on the configured server.
        # If <tt>:mode</tt> is specified it is used to set the mode on the file.

        def put(data, path, options = {})
          opts = options.dup
          upload(StringIO.new(data), path, opts)
        end

        # Get file remote_path from the configured server and transfer it to
        # local machine as path.
        #
        # get "#{deploy_to}/current/log/production.log", "log/production.log.web"

        def get(remote_path, path, options = {}, &block)
          download(remote_path, path, options, &block)
        end

        def upload(from, to, options = {}, &block)
          mode = options.delete(:mode)
          transfer(:up, from, to, options, &block)

          if mode
            mode = mode.is_a?(Numeric) ? mode.to_s(8) : mode.to_s
            run "chmod #{mode} #{to}", options
          end
        end

        alias upload_file upload

        def download(from, to, options = {}, &block)
          transfer(:down, from, to, options, &block)
        end

        def transfer(direction, from, to, options = {}, &block)
          if dry_run
            return logger.debug "transfering: #{[direction, from, to] * ', '}"
          end

          execute_on_server do
            Transfer.process(direction, from, to, session, options.merge(:logger => logger), &block)
          end
        end
      end
    end
  end
end
