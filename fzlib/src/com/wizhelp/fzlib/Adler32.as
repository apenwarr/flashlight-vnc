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

package com.wizhelp.fzlib {
	
	import mx.controls.Alert;
	
	
	public final class Adler32{
	
	  // largest prime smaller than 65536
	  static public const BASE:uint=65521; 
	  // NMAX is the largest n such that 255n(n+1)/2 + (n+1)(BASE-1) <= 2^32-1
	  static public const NMAX:uint=5552;
	
	  public function adler32(adler:uint, buf:*, index:uint, len:uint):uint {
	    if(buf == null){ return 1; }
	
	    var s1:uint=adler&0xffff;
	    var s2:uint=(adler>>16)&0xffff;
	    var k:uint;
	
	    while(len > 0) {
	      k=len<NMAX?len:NMAX;
	      len-=k;
	      while(k>=16){
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        s1+=buf[index++]; s2+=s1;
	        k-=16;
	      }
	      if(k!=0){
	        do{
	          s1+=buf[index++]; s2+=s1;
	        }
	        while(--k!=0);
	      }
	      s1%=BASE;
	      s2%=BASE;
	    }
	    
	    return (s2<<16)|s1;
	  }
	
	  /*
	  private java.util.zip.Adler32 adler=new java.util.zip.Adler32();
	  long adler32(long value, byte[] buf, int index, int len){
	    if(value==1) {adler.reset();}
	    if(buf==null) {adler.reset();}
	    else{adler.update(buf, index, len);}
	    return adler.getValue();
	  }
	  */
	}
}