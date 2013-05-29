#!/usr/bin/env ruby -w
#encoding: utf-8

require 'digest'
require 'socket'

# Comment this out to run a serial server
require 'celluloid/io'

class Prover
	include Celluloid::IO if defined?( Celluloid )

	DEFAULT_HOST = '0.0.0.0'
	DEFAULT_PORT = 1337

	def initialize( host=DEFAULT_HOST, port=DEFAULT_PORT )
		@socket = TCPServer.new( host, port )
		puts "Listening on %s:%d" % [ host, port ]
		async.run
	end

	if !defined?( Celluloid )
		def async; self; end
	end

	def run
		loop do
			conn = @socket.accept
			async.handle_connection( conn )
		end
	rescue => err
		$stderr.puts '%p while running: %s' % [ err.class, err.message ]
		$stderr.puts err.backtrace
	end


	def handle_connection( conn )
		print '.'
		conn.write( "ok\n" )

		hash = conn.readpartial( 4096 ).chomp
		conn.write( hash + ':' + work(hash) )

		conn.close
	end


	def work( input )
		id = 0
		nonce = id.to_s( 16 )

		until verify( input, nonce )
			id += 1
			nonce = id.to_s( 16 )
		end

		return nonce
	end


	def verify( input, nonce )
		hash = Digest::SHA256.new.update( input ).update( nonce )
		return hash.hexdigest.end_with?( '00' )
	end


	def shutdown
		@socket.close if @socket
	end

end # Prover


if __FILE__ == $0
	if defined?( Celluloid )
		supervisor = Prover.supervise( *ARGV )
		trap(:INT) { supervisor.terminate; exit }
		sleep
	else
		Prover.new( *ARGV )
	end
end

