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

package com.wizhelp.fzlib{
	import com.wizhelp.util.System;
	
internal final class InfBlocks{
  static private const MANY:int=1440;

  // And'ing with mask[n] masks the lower n bits
  static private const inflate_mask:Array= [
    0x00000000, 0x00000001, 0x00000003, 0x00000007, 0x0000000f,
    0x0000001f, 0x0000003f, 0x0000007f, 0x000000ff, 0x000001ff,
    0x000003ff, 0x000007ff, 0x00000fff, 0x00001fff, 0x00003fff,
    0x00007fff, 0x0000ffff];

  // Table for deflate from PKZIP's appnote.txt.
  internal static const border:Array= [ // Order of the bit length code lengths
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15];

  static private const Z_OK:int=0;
  static private const Z_STREAM_END:int=1;
  static private const Z_NEED_DICT:int=2;
  static private const Z_ERRNO:int=-1;
  static private const Z_STREAM_ERROR:int=-2;
  static private const Z_DATA_ERROR:int=-3;
  static private const Z_MEM_ERROR:int=-4;
  static private const Z_BUF_ERROR:int=-5;
  static private const Z_VERSION_ERROR:int=-6;

  static private const TYPE:int=0;  // get type bits (3, including end bit)
  static private const LENS:int=1;  // get lengths for stored
  static private const STORED:int=2;// processing stored block
  static private const TABLE:int=3; // get table lengths
  static private const BTREE:int=4; // get bit lengths tree for a dynamic block
  static private const DTREE:int=5; // get length, distance trees for a dynamic block
  static private const CODES:int=6; // processing fixed or dynamic block
  static private const DRY:int=7;   // output remaining window bytes
  static private const DONE:int=8;  // finished last block, done
  static private const BAD:int=9;   // ot a data error--stuck here

  internal var mode:int;            // current inflate_block mode 

  internal var left:int;            // if STORED, bytes left to copy 

  internal var table:int;           // table lengths (14 bits) 
  internal var index:int;           // index into blens (or border) 
  internal var blens:Array;         // bit lengths of codes 
  internal var bb:Array=new Array();; // bit length tree depth 
  internal var tb:Array=new Array();; // bit length decoding tree 

  internal var codes:InfCodes=new InfCodes();      // if CODES, current state 

  internal var last:int;            // true if this block is the last block 

  // mode independent information 
  internal var bitk:int;            // bits in bit buffer 
  internal var bitb:int;            // bit buffer 
  internal var hufts:Array;         // single malloc for tree space 
  internal var window:Array;       // sliding window 
  internal var end:int;             // one byte after sliding window 
  internal var read:int;            // window read pointer 
  internal var write:int;           // window write pointer 
  internal var checkfn:Object;      // check function 
  internal var check:uint;          // check on output 

  internal var inftree:InfTree=new InfTree();

  function InfBlocks(z:ZStream, checkfn:Object, w:int){
    hufts=new Array();
    window=new Array();
    end=w;
    this.checkfn = checkfn;
    mode = TYPE;
    reset(z, null);
  }

  internal function reset(z:ZStream, c:Array):void{
    if(c!=null) c[0]=check;
    if(mode==BTREE || mode==DTREE){
    }
    if(mode==CODES){
      codes.free(z);
    }
    mode=TYPE;
    bitk=0;
    bitb=0;
    read=write=0;

    if(checkfn != null)
      z.adler=check=z._adler.adler32(0, null, 0, 0);
  }

  internal function proc(z:ZStream, r:int):int{
    var t:int;              // temporary storage
    var b:int;              // bit buffer
    var k:int;              // bits in bit buffer
    var p:int;              // input data pointer
    var n:int;              // bytes available there
    var q:int;              // output window write pointer
    var m:int;              // bytes to end of window or read pointer

    // copy input/output information to locals (UPDATE macro restores)
    {p=z.next_in_index;n=z.avail_in;b=bitb;k=bitk;}
    {q=write;m=int((q<read?read-q-1:end-q));}

    // process input based on current state
    while(true){
      switch (mode){
      case TYPE:

	while(k<(3)){
	  if(n!=0){
	    r=Z_OK;
	  }
	  else{
	    bitb=b; bitk=k; 
	    z.avail_in=n;
	    z.total_in+=p-z.next_in_index;z.next_in_index=p;
	    write=q;
	    return inflate_flush(z,r);
	  };
	  n--;
	  b|=(z.next_in[p++]&0xff)<<k;
	  k+=8;
	}
	t = int((b & 7));
	last = t & 1;

	switch (t >>> 1){
        case 0:                         // stored 
          {b>>>=(3);k-=(3);}
          t = k & 7;                    // go to byte boundary

          {b>>>=t;k-=t;}
          mode = LENS;                  // get length of stored block
          break;
        case 1:                         // fixed
          {
            var bl:Array=new Array();
	    var bd:Array=new Array();
         var tl:Array=[new Array()];
	    var td:Array=[new Array()];

	    InfTree.inflate_trees_fixed(bl, bd, tl, td, z);
            codes.init(bl[0], bd[0], tl[0], 0, td[0], 0, z);
          }

          {b>>>=(3);k-=(3);}

          mode = CODES;
          break;
        case 2:                         // dynamic

          {b>>>=(3);k-=(3);}

          mode = TABLE;
          break;
        case 3:                         // illegal

          {b>>>=(3);k-=(3);}
          mode = BAD;
          z.msg = "invalid block type";
          r = Z_DATA_ERROR;

	  bitb=b; bitk=k; 
	  z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	  write=q;
	  return inflate_flush(z,r);
	}
	break;
      case LENS:

	while(k<(32)){
	  if(n!=0){
	    r=Z_OK;
	  }
	  else{
	    bitb=b; bitk=k; 
	    z.avail_in=n;
	    z.total_in+=p-z.next_in_index;z.next_in_index=p;
	    write=q;
	    return inflate_flush(z,r);
	  };
	  n--;
	  b|=(z.next_in[p++]&0xff)<<k;
	  k+=8;
	}

	if ((((~b) >>> 16) & 0xffff) != (b & 0xffff)){
	  mode = BAD;
	  z.msg = "invalid stored block lengths";
	  r = Z_DATA_ERROR;

	  bitb=b; bitk=k; 
	  z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	  write=q;
	  return inflate_flush(z,r);
	}
	left = (b & 0xffff);
	b = k = 0;                       // dump bits
	mode = left!=0? STORED : (last!=0? DRY : TYPE);
	break;
      case STORED:
	if (n == 0){
	  bitb=b; bitk=k; 
	  z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	  write=q;
	  return inflate_flush(z,r);
	}

	if(m==0){
	  if(q==end&&read!=0){
	    q=0; m=int((q<read?read-q-1:end-q));
	  }
	  if(m==0){
	    write=q; 
	    r=inflate_flush(z,r);
	    q=write;m=int((q<read?read-q-1:end-q));
	    if(q==end&&read!=0){
	      q=0; m=int((q<read?read-q-1:end-q));
	    }
	    if(m==0){
	      bitb=b; bitk=k; 
	      z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	      write=q;
	      return inflate_flush(z,r);
	    }
	  }
	}
	r=Z_OK;

	t = left;
	if(t>n) t = n;
	if(t>m) t = m;
	System.arraycopy(z.next_in, p, window, q, t);
	p += t;  n -= t;
	q += t;  m -= t;
	if ((left -= t) != 0)
	  break;
	mode = last!=0? DRY : TYPE;
	break;
      case TABLE:

	while(k<(14)){
	  if(n!=0){
	    r=Z_OK;
	  }
	  else{
	    bitb=b; bitk=k; 
	    z.avail_in=n;
	    z.total_in+=p-z.next_in_index;z.next_in_index=p;
	    write=q;
	    return inflate_flush(z,r);
	  };
	  n--;
	  b|=(z.next_in[p++]&0xff)<<k;
	  k+=8;
	}

	table = t = (b & 0x3fff);
	if ((t & 0x1f) > 29|| ((t >> 5) & 0x1f) > 29)
	  {
	    mode = BAD;
	    z.msg = "too many length or distance symbols";
	    r = Z_DATA_ERROR;

	    bitb=b; bitk=k; 
	    z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	    write=q;
	    return inflate_flush(z,r);
	  }
	t = 258+ (t & 0x1f) + ((t >> 5) & 0x1f);
	if(blens==null || blens.length<t){
	  blens=new Array();
	}
	else{
	  for(var ii:int=0; ii<t; ii++){blens[ii]=0;}
	}

	{b>>>=(14);k-=(14);}

	index = 0;
	mode = BTREE;
      case BTREE:
	while (index < 4+ (table >>> 10)){
	  while(k<(3)){
	    if(n!=0){
	      r=Z_OK;
	    }
	    else{
	      bitb=b; bitk=k; 
	      z.avail_in=n;
	      z.total_in+=p-z.next_in_index;z.next_in_index=p;
	      write=q;
	      return inflate_flush(z,r);
	    };
	    n--;
	    b|=(z.next_in[p++]&0xff)<<k;
	    k+=8;
	  }

	  blens[border[index++]] = b&7;

	  {b>>>=(3);k-=(3);}
	}

	while(index < 19){
	  blens[border[index++]] = 0;
	}

	bb[0] = 7;
	t = inftree.inflate_trees_bits(blens, bb, tb, hufts, z);
	if (t != Z_OK){
	  r = t;
	  if (r == Z_DATA_ERROR){
	    blens=null;
	    mode = BAD;
	  }

	  bitb=b; bitk=k; 
	  z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	  write=q;
	  return inflate_flush(z,r);
	}

	index = 0;
	mode = DTREE;
      case DTREE:
	while (true){
	  t = table;
	  if(!(index < 258+ (t & 0x1f) + ((t >> 5) & 0x1f))){
	    break;
	  }

	  var h:Array;
	  var i:int, j:int, c:int;

	  t = bb[0];

	  while(k<t){
	    if(n!=0){
	      r=Z_OK;
	    }
	    else{
	      bitb=b; bitk=k; 
	      z.avail_in=n;
	      z.total_in+=p-z.next_in_index;z.next_in_index=p;
	      write=q;
	      return inflate_flush(z,r);
	    };
	    n--;
	    b|=(z.next_in[p++]&0xff)<<k;
	    k+=8;
	  }

	  if(tb[0]==-1){
            //System.err.println("null...");
	  }

	  t=hufts[(tb[0]+(b&inflate_mask[t]))*3+1];
	  c=hufts[(tb[0]+(b&inflate_mask[t]))*3+2];

	  if (c < 16){
	    b>>>=t;k-=t;
	    blens[index++] = c;
	  }
	  else { // c == 16..18
	    i = c == 18? 7: c - 14;
	    j = c == 18? 11: 3;

	    while(k<(t+i)){
	      if(n!=0){
		r=Z_OK;
	      }
	      else{
		bitb=b; bitk=k; 
		z.avail_in=n;
		z.total_in+=p-z.next_in_index;z.next_in_index=p;
		write=q;
		return inflate_flush(z,r);
	      };
	      n--;
	      b|=(z.next_in[p++]&0xff)<<k;
	      k+=8;
	    }

	    b>>>=t;k-=t;

	    j += (b & inflate_mask[i]);

	    b>>>=i;k-=i;

	    i = index;
	    t = table;
	    if (i + j > 258+ (t & 0x1f) + ((t >> 5) & 0x1f) ||
		(c == 16&& i < 1)){
	      blens=null;
	      mode = BAD;
	      z.msg = "invalid bit length repeat";
	      r = Z_DATA_ERROR;

	      bitb=b; bitk=k; 
	      z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	      write=q;
	      return inflate_flush(z,r);
	    }

	    c = c == 16? blens[i-1] : 0;
	    do{
	      blens[i++] = c;
	    }
	    while (--j!=0);
	    index = i;
	  }
	}

	tb[0]=-1;
	{
	  var bl2:Array=new Array();
	  var bd2:Array=new Array();
	  var tl2:Array=new Array();
	  var td2:Array=new Array();
	  bl2[0] = 9;         // must be <= 9 for lookahead assumptions
	  bd2[0] = 6;         // must be <= 9 for lookahead assumptions

	  t = table;
	  t = inftree.inflate_trees_dynamic(257+ (t & 0x1f), 
					    1+ ((t >> 5) & 0x1f),
					    blens, bl2, bd2, tl2, td2, hufts, z);

	  if (t != Z_OK){
	    if (t == Z_DATA_ERROR){
	      blens=null;
	      mode = BAD;
	    }
	    r = t;

	    bitb=b; bitk=k; 
	    z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	    write=q;
	    return inflate_flush(z,r);
	  }
	  codes.init(bl2[0], bd2[0], hufts, tl2[0], hufts, td2[0], z);
	}
	mode = CODES;
      case CODES:
	bitb=b; bitk=k;
	z.avail_in=n; z.total_in+=p-z.next_in_index;z.next_in_index=p;
	write=q;

	if ((r = codes.proc(this, z, r)) != Z_STREAM_END){
	  return inflate_flush(z, r);
	}
	r = Z_OK;
	codes.free(z);

	p=z.next_in_index; n=z.avail_in;b=bitb;k=bitk;
	q=write;m=int((q<read?read-q-1:end-q));

	if (last==0){
	  mode = TYPE;
	  break;
	}
	mode = DRY;
      case DRY:
	write=q; 
	r=inflate_flush(z, r); 
	q=write; m=int((q<read?read-q-1:end-q));
	if (read != write){
	  bitb=b; bitk=k; 
	  z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	  write=q;
	  return inflate_flush(z, r);
	}
	mode = DONE;
      case DONE:
	r = Z_STREAM_END;

	bitb=b; bitk=k; 
	z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	write=q;
	return inflate_flush(z, r);
      case BAD:
	r = Z_DATA_ERROR;

	bitb=b; bitk=k; 
	z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	write=q;
	return inflate_flush(z, r);

      default:
	r = Z_STREAM_ERROR;

	bitb=b; bitk=k; 
	z.avail_in=n;z.total_in+=p-z.next_in_index;z.next_in_index=p;
	write=q;
	return inflate_flush(z, r);
      }
    }
    return 0;
  }

  internal function free(z:ZStream):void{
    reset(z, null);
    window=null;
    hufts=null;
    //ZFREE(z, s);
  }

  internal function set_dictionary(d:*, start:int, n:int):void{
    System.arraycopy(d, start, window, 0, n);
    read = write = n;
  }

  // Returns true if inflate is currently at the end of a block generated
  // by Z_SYNC_FLUSH or Z_FULL_FLUSH. 
  internal function sync_point():int{
    return mode == LENS ? 1: 0;
  }

  // copy as much as possible from the sliding window to the output area
  internal function inflate_flush(z:ZStream, r:int):int{
    var n:int;
    var p:int;
    var q:int;

    // local copies of source and destination pointers
    p = z.next_out_index;
    q = read;

    // compute number of bytes to copy as far as end of window
    n = int(((q <= write ? write : end) - q));
    if (n > z.avail_out) n = z.avail_out;
    if (n!=0&& r == Z_BUF_ERROR) r = Z_OK;

    // update counters
    z.avail_out -= n;
    z.total_out += n;

    // update check information
    if(checkfn != null)
      z.adler=check=z._adler.adler32(check, window, q, n);

    // copy as far as end of window
    System.arraycopy(window, q, z.next_out, p, n);
    p += n;
    q += n;

    // see if more to copy at beginning of window
    if (q == end){
      // wrap pointers
      q = 0;
      if (write == end)
        write = 0;

      // compute bytes to copy
      n = write - q;
      if (n > z.avail_out) n = z.avail_out;
      if (n!=0&& r == Z_BUF_ERROR) r = Z_OK;

      // update counters
      z.avail_out -= n;
      z.total_out += n;

      // update check information
      if(checkfn != null)
	z.adler=check=z._adler.adler32(check, window, q, n);

      // copy
      System.arraycopy(window, q, z.next_out, p, n);
      p += n;
      q += n;
    }

    // update pointers
    z.next_out_index = p;
    read = q;

    // done
    return r;
  }
}}