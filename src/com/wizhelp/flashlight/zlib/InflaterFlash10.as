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
*/

package com.wizhelp.flashlight.zlib
{
	import com.wizhelp.fzlib.FZlib;
	import com.wizhelp.fzlib.ZStream;
	
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	
	public class InflaterFlash10
	{
		private var lastDeflate:ByteArray;
		private var firstBlock:Boolean = true;
		public var uncompressedData:ByteArray;
		
		public function InflaterFlash10() {
			lastDeflate = new ByteArray();
		}
		
		
		public function inflate(data:ByteArray, compressedDataSize:int, uncompressedDataSize:int):void {
			uncompressedData = new ByteArray();
			var dictionarySize:int = lastDeflate.length > 32768 ? 32768 : lastDeflate.length;
			var dataOffset:int = firstBlock ? 2 : 0;
			uncompressedData.writeByte(0x00);
			uncompressedData.writeByte(dictionarySize );
			uncompressedData.writeByte(dictionarySize >> 8);
			uncompressedData.writeByte(~dictionarySize);
			uncompressedData.writeByte((~dictionarySize) >> 8 );
			uncompressedData.writeBytes(lastDeflate,lastDeflate.length - dictionarySize, dictionarySize);
			
			uncompressedData.writeBytes(data,dataOffset,compressedDataSize-dataOffset);
			uncompressedData.writeByte(0x01);
			uncompressedData.writeUnsignedInt(0x0000FFFF);
			
			uncompressedData.flash10::inflate();
			
			lastDeflate = uncompressedData;
			uncompressedData.position = dictionarySize;
			
			firstBlock = false;
		}
	}
}