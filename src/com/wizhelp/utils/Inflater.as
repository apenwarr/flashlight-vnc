/*

	Copyright (C) 2008 Marco Fucci

	This library is free software; you can redistribute it and/or
	modify it under the terms of the GNU Library General Public
	License as published by the Free Software Foundation; either
	version 2 of the License, or (at your option) any later version.
	
	This library is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	Library General Public License for more details.
	
	You should have received a copy of the GNU Library General Public
	License along with this library; if not, write to the Free Software
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
	
	Contact : mfucci@gmail.com
	
*/

/*
	Uncompress a stream of Zlib data.
	Use Flash 10 native functions if available, with a lot of hacking
	
	TODO: rewrite this for multi-threading support
*/

package com.wizhelp.utils
{
	import com.wizhelp.fzlib.FZlib;
	import com.wizhelp.fzlib.ZStream;
	
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	
	public class Inflater
	{
		private static var useNativeInflater:*;
		
		// flash 10
		private var lastDeflate:ByteArray;
		private var firstBlock:Boolean = true;
		
		// flash 9
		private var zstream:ZStream;
		
		public function Inflater() {
			
			if (useNativeInflater === undefined) {
				// on first instance, detect flash player version
				var playerVersion:String = Capabilities.version;
				if (String(playerVersion.split(' ')[1]).substr(0,2) == "10") {
					useNativeInflater = true;
				} else {
					useNativeInflater = false;
				}
			}
				
			if (!useNativeInflater) {
				// support for flash 9
				zstream = new ZStream();
				var err:int=zstream.inflateInit();
				if (err!=FZlib.Z_OK) {
					throw new Error(zstream.msg,err);
				}
			} else {
				// support for flash 10
				lastDeflate = new ByteArray();
			}
		}
		
		
		public function inflate(data:ByteArray, compressedDataSize:int, uncompressedDataSize:int):ByteArray {
			var i:int;
			
			var deflateData:ByteArray = new ByteArray();
			
			if (!useNativeInflater) {
				// support for flash 9
				
				zstream.next_in=data;
				zstream.next_in_index=0;
				zstream.avail_in = compressedDataSize;
				
				zstream.next_out=deflateData;
			    zstream.next_out_index=0;
			    zstream.avail_out=uncompressedDataSize;
		        var err:int=zstream.inflate(FZlib.Z_NO_FLUSH);
		        if (err!=FZlib.Z_OK) {
				  throw new Error(zstream.msg,err);
			    }
			} else {
				// support for flash 10
				
				var dictionarySize:int = lastDeflate.length > 32768 ? 32768 : lastDeflate.length;
				var dataOffset:int = firstBlock ? 2 : 0;
				deflateData.writeByte(0x00);
				deflateData.writeByte(dictionarySize );
				deflateData.writeByte(dictionarySize >> 8);
				deflateData.writeByte(~dictionarySize);
				deflateData.writeByte((~dictionarySize) >> 8 );
				deflateData.writeBytes(lastDeflate,lastDeflate.length - dictionarySize, dictionarySize);
				
				deflateData.writeBytes(data,dataOffset,compressedDataSize-dataOffset);
				deflateData.writeByte(0x01);
				deflateData.writeUnsignedInt(0x0000FFFF);
				
				deflateData.flash10::inflate();
				
				lastDeflate = deflateData;
				deflateData.position = dictionarySize;
				
				firstBlock = false;
			}
			
			return deflateData;
		}
	}
}