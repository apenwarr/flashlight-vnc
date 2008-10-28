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
	Read RFB protocol.
*/

package com.wizhelp.flashlight.rfb
{
	import com.wizhelp.flashlight.codec.CodecCopyRect;
	import com.wizhelp.flashlight.codec.CodecCursorPos;
	import com.wizhelp.flashlight.codec.CodecRaw;
	import com.wizhelp.flashlight.codec.CodecRichCursor;
	import com.wizhelp.flashlight.codec.CodecTight;
	import com.wizhelp.flashlight.thread.DataHandler;
	import com.wizhelp.flashlight.vnc.VNCHandler;
	
	import flash.display.BitmapData;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	public class RFBReader
	{
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.rfb.RFBReader');
    
    	public var framebufferWidth:int;
		public var framebufferHeight:int;
		private var bitsPerPixel:int;
		private var depth:int;
		public var bigEndian:Boolean;
		public var trueColour:Boolean;
		public var redMax:int;
		public var greenMax:int;
		public var blueMax:int;
		public var redShift:int;
		public var greenShift:int;
		public var blueShift:int;
		public var redMask:int;
		public var greenMask:int;
		public var blueMask:int;
		public var desktopName:String;
		public var bytesPerPixel:int;
		public var bytesPerPixelDepth:int;
		
		private var updateNRects:int;
		public var updateRectX:int;
	    public var updateRectY:int;
	    public var updateRectW:int;
	    public var updateRectH:int;
	    public var updateRect:Rectangle;
	    private var updateRectEncoding:uint;
	    
		private var paused:Boolean = false;
		private var tmpStream:IDataInput;
		
		public var rfbStack:Array = new Array();
		
		private var encodingTight:CodecTight;
		private var encodingCopyRect:CodecCopyRect;
		private var encodingRaw:CodecRaw;
		private var encodingRichCursor:CodecRichCursor;
		private var encodingCursorPos:CodecCursorPos;
		
		private var vncHandler:VNCHandler;
		
		public var input:IDataInput;
		
		
		public function RFBReader(vncHandler:VNCHandler,async:Boolean)
		{
			encodingTight = new CodecTight(vncHandler, this,async);
			encodingCopyRect = new CodecCopyRect(vncHandler, this);
			encodingRaw = new CodecRaw(vncHandler, this);
			encodingRichCursor = new CodecRichCursor(vncHandler, this);
			encodingCursorPos = new CodecCursorPos(vncHandler, this);
			
			this.vncHandler = vncHandler;
			
			rfbStack.push(handleRFB);
		}
		
		public function hasEnoughData():Boolean {
			if (rfbStack.length > 0 && input.bytesAvailable >= rfbStack[0].bytesNeeded) {
				return true;
			}
			return false;
		}
		
		public function run():void {
			var rfbHandler:DataHandler = rfbStack.shift();
			//logger.timeStart("total");
			try {
				rfbHandler.call.apply(rfbHandler.object,[input]);
			} catch (e:Error) {
				logger.error("An unexpected error occured when reading RFB protocol : "+e.errorID+" "+e.name+" "+e.message+" "+e.getStackTrace());
				throw e;
			}
			//logger.timeEnd("total");
		}
		
		private var handleRFB:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				logger.debug(">> handleRFB()");
				
				rfbStack.push(handleRFBVersion);
				rfbStack.push(handleRFBSecurity);
				rfbStack.push(handleServerInit);
				rfbStack.push(handleDesktopName);
				rfbStack.push(handleServerMessage);
				
				logger.debug("<< handleRFB()");
			},
			this);
		
		private var handleRFBVersion:DataHandler = new DataHandler(
			12,
			function(stream:IDataInput):void {
				logger.debug(">> handleRFBVersion()");
				
				var version:String = stream.readUTFBytes(12);
				vncHandler.handleServerVersion(version);
				//output.text+="RFB Version : "+version;
				
				logger.debug("<< handleRFBVersion()");
			},
			this);
		
		private var handleRFBSecurity:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				logger.debug(">> handleRFBSecurity()");
				
				var secType:int = stream.readUnsignedInt();
				
				switch (secType) {
					case RFBConst.SecTypeNone:
						vncHandler.handleNoAuth();
						break;
					case RFBConst.SecTypeVncAuth:
						rfbStack.unshift(
							handleVNCAuth,
							handleRFBSecurityResult);
						break;
					default :
						throw new Error("Unsuported security type : "+ secType);
				}
				
				logger.debug("<< handleRFBSecurity()");
			},
			this);
			
		private var handleVNCAuth:DataHandler = new DataHandler(
			16,
			function(stream:IDataInput):void {
				var challenge:ByteArray = new ByteArray();
				challenge.length = 16;
				stream.readBytes(challenge);
				
				vncHandler.handleVNCAuth(challenge);
			},
			this);
			
		private var handleRFBSecurityResult:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				logger.debug(">> handleRFBSecurityResult()");
				
				var authResult:int = stream.readUnsignedInt();
				
				switch (authResult) {
					case RFBConst.VncAuthOK:
						vncHandler.handleAuthOk();
						return;
					case RFBConst.VncAuthFailed:
						throw new Error("Authentication failed");
					case RFBConst.VncAuthTooMany:
						throw new Error("Too many authentication tries");
					default :
						throw new Error("Unsuported security result : "+ authResult);
				}
				
				logger.debug("<< handleRFBSecurityResult()");
			},
			this);
		
		private var handleServerInit:DataHandler = new DataHandler(
			24,
			function(stream:IDataInput):void {
				framebufferWidth = stream.readUnsignedShort();
			    framebufferHeight = stream.readUnsignedShort();
			    
			    var pixelFormat:RFBPixelFormat = new RFBPixelFormat();
			  	pixelFormat.bitsPerPixel = stream.readUnsignedByte();
			    pixelFormat.depth = stream.readUnsignedByte();
			    pixelFormat.bigEndian = stream.readBoolean();
			    pixelFormat.trueColour = stream.readBoolean();
			    pixelFormat.redMax = stream.readUnsignedShort();
			    pixelFormat.greenMax = stream.readUnsignedShort();
			    pixelFormat.blueMax = stream.readUnsignedShort();
			    pixelFormat.redShift = stream.readUnsignedByte();
			    pixelFormat.greenShift = stream.readUnsignedByte();
			    pixelFormat.blueShift = stream.readUnsignedByte();
			    stream.readByte();
			    stream.readByte();
			    stream.readByte();
			    handleDesktopName.bytesNeeded = stream.readInt();
			   
				setPixelFormat(pixelFormat);
			},
			this);
			
		public function setPixelFormat(pixelFormat:RFBPixelFormat):void {
			trueColour = pixelFormat.trueColour;
			bigEndian = pixelFormat.bigEndian;
			depth = pixelFormat.depth;
			bitsPerPixel = pixelFormat.bitsPerPixel;
			bytesPerPixel = (bitsPerPixel+7)/8;
			bytesPerPixelDepth = (depth+7)/8;
			
			redMax = pixelFormat.redMax;
			greenMax = pixelFormat.greenMax;
			blueMax = pixelFormat.blueMax;
				
			redMask = pixelFormat.redMax << pixelFormat.redShift;
			greenMask = pixelFormat.greenMax << pixelFormat.greenShift;
			blueMask = pixelFormat.blueMax << pixelFormat.blueShift;
			
			redShift = 16 - pixelFormat.redShift;
			greenShift = 8 - pixelFormat.greenShift;
			blueShift = pixelFormat.blueShift;
			
			for (var i:int=128;i>0;i>>=1) {
				if ((redMax & i) == 0) redShift++;
				if ((greenMax & i) == 0) greenShift++;
				if ((blueMax & i) == 0) blueShift++;
			}
			
			if (Log.isDebug()) {
				logger.debug("bytesPerPixel : "+bytesPerPixel);
				logger.debug("bitsPerPixel : "+bitsPerPixel);
				logger.debug("depth : "+depth);
				logger.debug("trueColour : "+trueColour);
				logger.debug("bigEndian : "+bigEndian);
				
				logger.debug("redMask : "+redMask.toString(2));
				logger.debug("greenMask : "+greenMask.toString(2));
				logger.debug("blueMask : "+blueMask.toString(2));
				
				logger.debug("redShift : "+redShift);
				logger.debug("greenShift : "+greenShift);
				logger.debug("blueShift : "+blueShift);
			}
		}
			
		private var handleDesktopName:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				desktopName = stream.readUTFBytes(handleDesktopName.bytesNeeded);
				vncHandler.handleServerInit(desktopName, new Point(framebufferWidth,framebufferHeight));
			},
			this);
		
		private var handleServerMessage:DataHandler = new DataHandler(
			1,
			function(stream:IDataInput):void {
				var messageType:int = stream.readUnsignedByte();
				//output.text+="messageType : "+messageType+"\n";
				
				switch (messageType) {
					case RFBConst.FramebufferUpdate:
						rfbStack.push(handleFramebufferUpdate);
						break;
					case RFBConst.Bell:
						break;
					case RFBConst.ServerCutText:
						rfbStack.push(handleServerCutText);
						break;
					default :
						throw new Error("Unsuported message type : "+ messageType);
				}
				
				rfbStack.push(handleServerMessage);
			},
			this);
			
		private var handleServerCutText:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				stream.readByte();
				stream.readByte();
				stream.readByte();
				
				var textSize:int = stream.readUnsignedInt();
				handleServerCutTextData.bytesNeeded = textSize;
				
				rfbStack.unshift(handleServerCutTextData);
			},
			this);
		
		private var handleServerCutTextData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				var remoteText:String = stream.readUTFBytes(handleServerCutTextData.bytesNeeded);
				logger.debug("remote text : "+remoteText);
			},
			this);
		
		private var handleFramebufferUpdate:DataHandler = new DataHandler(
			3,
			function(stream:IDataInput):void {
				stream.readByte();
				updateNRects = stream.readUnsignedShort();
				
				//output.text+="updateNRects : "+updateNRects+"\n";
				if (updateNRects>0) {
					//newImageData = imageData;
					//newImageData = new BitmapData(framebufferWidth, framebufferHeight,false,0xFF000000);
					//newImageData.copyPixels(imageData,imageData.rect,new Point(0,0));
					//newImageData.lock();
					rfbStack.unshift(handleFramebufferUpdateRect);
				}
			},
			this);
		
		private var handleFramebufferUpdateRect:DataHandler = new DataHandler(
			12,
			function(stream:IDataInput):void {
				var tmp:BitmapData;
				
				updateRectX = stream.readUnsignedShort();
	    		updateRectY = stream.readUnsignedShort();
	    		updateRectW = stream.readUnsignedShort();
	    		updateRectH = stream.readUnsignedShort();
	    		updateRect = new Rectangle(
	    			updateRectX,
	    			updateRectY,
	    			updateRectW,
	    			updateRectH);
	    		updateRectEncoding = stream.readUnsignedInt();
	    		
				//logger.log("Update rect "+updateRectX+" "+updateRectY+" "+updateRectW+" "+updateRectH);
				
				updateNRects--;
				if (updateRectEncoding == RFBConst.EncodingLastRect) {
					vncHandler.handleFrameBufferUpdated();
					return;
				}
				if (updateNRects>0) {
					rfbStack.unshift(handleFramebufferUpdateRect);
				}
	    		
	    		switch (updateRectEncoding) {
	    			case RFBConst.EncodingRaw :
						//output.text+="EncodingTight\n";
						encodingRaw.bytesNeeded = bytesPerPixel*updateRectW*updateRectH;
	    				rfbStack.unshift(encodingRaw);
	    				break;
	    			case RFBConst.EncodingCopyRect :
						//output.text+="EncodingCopyRect\n";
	    				rfbStack.unshift(encodingCopyRect);
	    				break;
	    			case RFBConst.EncodingTight :
						//logger.log("EncodingTight");
	    				rfbStack.unshift(encodingTight);
	    				break;
			   		case RFBConst.EncodingXCursor :
	    				throw new Error("Unsuported encoding : EncodingXCursor");
	    				break;
			   		case RFBConst.EncodingRichCursor :
			   			encodingRichCursor.bytesNeeded =  bytesPerPixel*updateRectW*updateRectH + int((updateRectW+7) / 8)*updateRectH;
			   			rfbStack.unshift(encodingRichCursor);
	    				break;
			   		case RFBConst.EncodingPointerPos :
			   			rfbStack.unshift(encodingCursorPos);
	    				break;
			   		case RFBConst.EncodingNewFBSize :
	    				throw new Error("Unsuported encoding : EncodingNewFBSize");
	    				break;
	    			default :
	    				throw new Error("Unsuported encoding : "+ updateRectEncoding.toString(16));
	    		}
	    		
	    		if (updateNRects == 0) {
					vncHandler.handleFrameBufferUpdated();
	    		}
			},
			this);
		
		/*public function pause(stream:IDataInput):void {
			tmpStream = stream;
			paused = true;
		}
		
		public function resume():void {
			paused=false;
			//output.text+=(tmpStream==null)+"\n";
			handleData(tmpStream);
			if (!paused) {
				tmpStream = null;
			}
		}*/
			
		/*public function readPixels2(input:ByteArray,output:BitmapData,length:int):void {
			var x:int, y:int, i:int;
			var readPos:int = 0;
			var writePos:int = 0;
			
			if (trueColour) {
				for (y=updateRectY;y<updateRectY+updateRectH;y++) {
					for (x=updateRectX;x<updateRectX+updateRectW;x++) {
						var color:uint=0;
						
						if (bigEndian) {
							for (i=0;i<depth;i+=8) {
								color |= input[readPos++] << i;
							}
						} else {
							for (i=depth-8;i>=0;i-=8) {
								color |= input[readPos++] << i;
							}
						}
						
						color = 0xFF000000 |
								(color & redMask) << redShift |
								(color & greenMask) << greenShift |
								(color & blueMax) << blueShift;
						output.setPixel(x,y,color);
					}
				}
			} else {
				throw new Error("Indexed color ");
			}
		}*/
		
		
		/* Reads a block of pixels
		 * handles tight format using depth instead of bitsPerPixel
		 * TODO: optimize this with:
		 		_BitmapData.setPixels() hacks
		 		_uncompressed 16bits depth as indexed color
		 */
		public function readPixels(input:ByteArray,output:ByteArray,length:int,useDepth:Boolean = false):void {
			var i:int, j:int;
			var readPos:int = 0;
			var writePos:int = 0;
			
			if (trueColour) {
				/*if (redShift == 0 && blueShift == 0 && greenShift == 0 && depth == 24) {
					for (j=0;j<length;j++) {
						output[writePos++] = 0xFF;
						output[writePos++] = input[readPos++];
						output[writePos++] = input[readPos++];
						output[writePos++] = input[readPos++];
					}
				} else if (redShift == 0 && blueShift == 0 && greenShift == 0 && depth == 32) {
					for (j=0;j<length;j++) {
						if (bigEndian) {
							output[writePos++] = input[readPos+3];
							output[writePos++] = input[readPos+2];
							output[writePos++] = input[readPos+1];
							output[writePos++] = input[readPos];
							readPos+=4;
						} else {
							output[writePos++] = input[readPos++];
							output[writePos++] = input[readPos++];
							output[writePos++] = input[readPos++];
							output[writePos++] = input[readPos++];
						}
					}
					output.position = 0;
					input.position = 0;
					output.readBytes(input,0,length);
					output.position = 0;
					input.position = 0;
				} else {*/
					for (j=0;j<length;j++) {
						var color:uint=0;
						var shift:int = 0;
						
						if (!useDepth) {
							if (!bigEndian) {
								for (i=0;i<bytesPerPixel;i++) {
									color |= input[readPos++] <<shift;
									shift+=8;
								}
							} else {
								for (i=0;i<bytesPerPixel;i++) {
									color <<= 8;
									color |= input[readPos++];
								}
							}
						} else {
							if (!bigEndian) {
								for (i=0;i<bytesPerPixelDepth;i++) {
									color <<= 8;
									color |= input[readPos++];
								}
							} else {
								for (i=0;i<bytesPerPixelDepth;i++) {
									color |= input[readPos++] <<shift;
									shift+=8;
								}
							}
						}
						
						output[writePos++] = 0xFF;
						output[writePos++] = (color & redMask) >> (16-redShift);
						output[writePos++] = (color & greenMask) >> (8-greenShift);
						output[writePos++] = (color & blueMask) << blueShift;
					}
				//}
			} else {
				throw new Error("Indexed color ");
			}
		}
		
		/*public function readPixel2(stream:ByteArray,pos:int):uint {
			var color:uint=0;
			var i:int;
			var posByte:int = pos*bytesPerPixel;
			if (trueColour) {
				if (bigEndian) {
					for (i=0;i<depth;i+=8) {
						color |= stream[posByte++] << i;
					}
				} else {
					for (i=depth-8;i>=0;i-=8) {
						color |= stream[posByte++] << i;
					}
				}
				color = 0xFF000000 |
						(color & redMask) << redShift |
						(color & greenMask) << greenShift |
						(color & blueMax) << blueShift;
			} else {
				throw new Error("Indexed color ");
			}
			return color;
		}*/
		
		/* Reads a pixel
		 * Don't use this to read a block of pixels !
		 * handles tight format using depth instead of bitsPerPixel
		 * TODO: optimize this with:
		 		_BitmapData.setPixels() hacks
		 		_uncompressed 16bits depth as indexed color
		 */
		public function readPixel(stream:IDataInput,useDepth:Boolean = false):uint {
			var color:uint=0;
			var i:int;
			if (trueColour) {
				var shift:int = 0;
				//logger.log(stream.bytesAvailable+"");
				
				if (!useDepth) {
					if (!bigEndian) {
						for (i=0;i<bytesPerPixel;i++) {
							color |= stream.readUnsignedByte() <<shift;
							shift+=8;
						}
					} else {
						for (i=0;i<bytesPerPixel;i++) {
							color <<= 8;
							color |= stream.readUnsignedByte();
						}
					}
				} else {
					if (!bigEndian) {
						for (i=0;i<bytesPerPixelDepth;i++) {
							color <<= 8;
							color |= stream.readUnsignedByte();
						}
					} else {
						for (i=0;i<bytesPerPixelDepth;i++) {
							color |= stream.readUnsignedByte() <<shift;
							shift+=8;
						}
					}
				}
				//logger.log(stream.bytesAvailable+"");
				
				//logger.log(color.toString(16));
				
				color = 0xFF000000 |
						(color & redMask) << redShift |
						(color & greenMask) << greenShift |
						(color & blueMask) << blueShift;
				
				//logger.log(color.toString(16));
			} else {
				throw new Error("Indexed color ");
			}
			return color;
		}
		

	}
}