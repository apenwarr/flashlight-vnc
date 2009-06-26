/*
Copyright (c) 2008 Marco Fucci. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
     this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright 
     notice, this list of conditions and the following disclaimer in 
     the documentation and/or other materials provided with the distribution.

3. The names of the authors may not be used to endorse or promote products
     derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESSED OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL JCRAFT,
INC. OR ANY CONTRIBUTORS TO THIS SOFTWARE BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 * This program is a port of JZlib ( (c) JCraft ) to ActionScript.
 * http://www.jcraft.com/jzlib/
 */

/*
 * This program is based on zlib-1.1.3, so all credit should go authors
 * Jean-loup Gailly(jloup@gzip.org) and Mark Adler(madler@alumni.caltech.edu)
 * and contributors of zlib.
 */
 
package com.wizhelp.util
{
	import flash.utils.ByteArray;
	
	final public class System
	{
		public static function arraycopy(src:*, srcOffset:int, dst:*, dstOffset:int, len:int):void
		{
			for (var i:int=0;i<len;i++) {
				dst[i+dstOffset]=src[i+srcOffset];
			}
		}
		
		public static function stringToArray(string:String):Array {
			var array:Array = new Array();
			var temp:ByteArray = new ByteArray();
			temp.writeUTF(string);
			temp.position=2;
			for (var i:int=0;i<temp.length-2;i++) {
				array[i]=temp.readByte();
			}
			return array;
		}
		
		public static function arrayToString(array:Array):String {
			var temp:ByteArray = new ByteArray();
			temp.writeShort(array.length);
			for (var i:int=0;i<array.length;i++) {
				temp.writeByte(array[i]);
			}
			temp.position=0;
			return temp.readUTF();
		}
	}
}