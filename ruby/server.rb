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
		_, port, addr = conn.peeraddr

		puts "connection on port %d from %s" % [ port, addr ]
		bytes = conn.write( "ok\n" )

		puts "  [#{port}] wrote greeting (%d bytes). Reading..." % [ bytes ]
		hash = conn.readpartial( 4096 )
		hash.chomp!

		puts "  [#{port}] read the hash (%p)" % [ hash ]
		nonce = work( hash )
		result = [hash, nonce].map( &:to_s ).join(':')
		conn.write( result )

		puts "  [#{port}] wrote the result: %p" % [ result ]
		conn.close
	end


	def work( input )
		puts "Starting work"
		start = Time.now
		id = 0
		nonce = id.to_s( 16 )
		until verify( input, nonce )
			id += 1
			nonce = id.to_s( 16 )
		end
		puts "Work done in %0.3fs" % [ Time.now - start ]

		return nonce
	end


	def verify( input, nonce )
		hash = Digest::SHA256.new
		hash.update( input )
		hash.update( nonce )

		return hash.hexdigest.end_with?( '00' )
	end


	def shutdown
		@socket.close if @socket
	end

end # Prover


if __FILE__ == $0
	Encoding.default_external = Encoding::US_ASCII

	if defined?( Celluloid )
		supervisor = Prover.supervise( *ARGV )
		trap(:INT) { supervisor.terminate; exit }
		sleep
	else
		Prover.new( *ARGV ).run
	end
end

