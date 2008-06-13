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
	Support of RFB protocol.
*/

package com.wizhelp.fvnc
{
	import com.wizhelp.fvnc.codec.CodecCopyRect;
	import com.wizhelp.fvnc.codec.CodecCursorPos;
	import com.wizhelp.fvnc.codec.CodecRaw;
	import com.wizhelp.fvnc.codec.CodecRichCursor;
	import com.wizhelp.fvnc.codec.CodecTight;
	
	import flash.display.BitmapData;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.Socket;
	import flash.ui.Keyboard;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	
	public class RFB
	{
		private var logger:Logger = new Logger(this);
		
		// Supported authentication types
		public static const SecTypeInvalid:int = 0;
		public static const SecTypeNone:int    = 1;
		public static const SecTypeVncAuth:int = 2;
		public static const SecTypeTight:int   = 16;
		
 		// VNC authentication results
		public static const VncAuthOK:int      = 0;
		public static const VncAuthFailed:int  = 1;
		public static const VncAuthTooMany:int = 2;
		
		  // Server-to-client messages
		public static const FramebufferUpdate:int    = 0;
		public static const SetColourMapEntries:int = 1;
		public static const Bell:int                			 = 2;
		public static const ServerCutText:int       	 = 3;
		
		// Encodings
		public static const EncodingRaw:uint            = 0;
   		public static const EncodingCopyRect:uint       = 1;
   		public static const EncodingRRE:uint            = 2;
   		public static const EncodingCoRRE:uint          = 4;
   		public static const EncodingHextile:uint        = 5;
   		public static const EncodingZlib:uint           = 6;
   		public static const EncodingTight:uint          = 7;
   		public static const EncodingZRLE:uint           = 16;
   		public static const EncodingCompressLevel0:uint = 0xFFFFFF00;
   		public static const EncodingQualityLevel0:uint  = 0xFFFFFFE0;
   		public static const EncodingXCursor:uint        = 0xFFFFFF10;
   		public static const EncodingRichCursor:uint     = 0xFFFFFF11;
   		public static const EncodingPointerPos:uint     = 0xFFFFFF18;
   		public static const EncodingLastRect:uint       = 0xFFFFFF20;
   		public static const EncodingNewFBSize:uint      = 0xFFFFFF21;
   		
   		// Client commands
   		public static const SetPixelFormat:int = 0;
		public static const FixColourMapEntries:int = 1;
		public static const SetEncodings:int = 2;
		public static const FramebufferUpdateRequest:int = 3;
		public static const KeyboardEvent:int = 4;
		public static const PointerEvent:int = 5;
		public static const ClientCutText:int = 6;
    
    	public var framebufferWidth:int;
		public var framebufferHeight:int;
		private var bitsPerPixel:int;
		private var depth:int;
		private var bigEndian:Boolean;
		private var trueColour:Boolean;
		private var redMax:int;
		private var greenMax:int;
		private var blueMax:int;
		private var redShift:int;
		private var greenShift:int;
		private var blueShift:int;
		private var redMask:int;
		private var greenMask:int;
		private var blueMask:int;
		private var desktopName:String;
		public var bytesPerPixel:int;
		public var bytesPerPixelDepth:int;
		
		private var imageData:BitmapData;
		private var newImageData:BitmapData;
		
		private var updateNRects:int;
		public var updateRectX:int;
	    public var updateRectY:int;
	    public var updateRectW:int;
	    public var updateRectH:int;
	    public var updateRect:Rectangle;
	    private var updateRectEncoding:uint;
	    
		private var paused:Boolean = false;
		private var tmpStream:IDataInput;
		
		public var rawDataBuffer:ByteArray = new ByteArray();
		public var pixelsBuffer:ByteArray = new ByteArray();
		
		public var rfbStack:Array = new Array();
		private var rfbHandler:DataHandler;
		
		private var encodingTight:CodecTight;
		private var encodingCopyRect:CodecCopyRect;
		private var encodingRaw:CodecRaw;
		private var encodingRichCursor:CodecRichCursor;
		private var encodingCursorPos:CodecCursorPos;
		
		public var onServerVersion:Function;
		public var onAuthOk:Function;
		public var onServerInit:Function;
		public var onFrameBufferUpdate:Function;
		public var onVNCAuth:Function;
		public var onCursorShapeUpdate:Function;
		public var onCursorPositionUpdate:Function;
		
		private var fvnc:FVNC;
		
		public function RFB(fvnc:FVNC)
		{
			encodingTight = new CodecTight(this);
			encodingCopyRect = new CodecCopyRect(this);
			encodingRaw = new CodecRaw(this);
			encodingRichCursor = new CodecRichCursor(this);
			encodingCursorPos = new CodecCursorPos(this);
			
			rfbHandler = handleRFB;
			
			this.fvnc = fvnc;
		}
		
		public function handleData(stream:IDataInput):void {
			try {
				/*if (rfbHandler != null) 
					output.text="incoming data ++++++++++ \n";*/
					//logger.log("init "+stream.bytesAvailable+"");
				while (rfbHandler != null && !paused && stream.bytesAvailable >= rfbHandler.bytesNeeded ) {
					//logger.log(stream.bytesAvailable+"");
					//output.text+=stream.bytesAvailable+"\n";
					logger.timeStart("total");
					rfbHandler.call(stream);
					logger.timeEnd("total");
					//logger.log(stream.bytesAvailable+"");
					rfbHandler = rfbStack.shift();
				}
				/*if (rfbHandler != null)
					output.text+="++++++++++ end \n";*/
			} catch (e:Error) {
				logger.log("Error : "+e.message+" "+e.getStackTrace());
				rfbHandler = null;
			}
		}
		
		private var handleRFB:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				rfbStack.push(handleRFBVersion);
				rfbStack.push(handleRFBSecurity);
				rfbStack.push(handleServerInit);
				rfbStack.push(handleDesktopName);
				rfbStack.push(handleServerMessage);
			});
		
		private var handleRFBVersion:DataHandler = new DataHandler(
			12,
			function(stream:IDataInput):void {
				var version:String = stream.readUTFBytes(12);
				onServerVersion(version);
				//output.text+="RFB Version : "+version;
			});
		
		private var handleRFBSecurity:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				var secType:int = stream.readUnsignedInt();
				
				switch (secType) {
					case SecTypeNone:
						return;
					case SecTypeVncAuth:
						rfbStack.unshift(
							handleVNCAuth,
							handleRFBSecurityResult);
						return;
					default :
						throw new Error("Unsuported security type : "+ secType);
				}
			});
			
		private var handleVNCAuth:DataHandler = new DataHandler(
			16,
			function(stream:IDataInput):void {
				var challenge:ByteArray = new ByteArray();
				challenge.length = 16;
				stream.readBytes(challenge);
				
				onVNCAuth(challenge);
			});
			
		private var handleRFBSecurityResult:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				var authResult:int = stream.readUnsignedInt();
				
				switch (authResult) {
					case VncAuthOK:
						onAuthOk();
						return;
					case VncAuthFailed:
						throw new Error("Authentication failed");
					case VncAuthTooMany:
						throw new Error("Too many authentication tries");
					default :
						throw new Error("Unsuported security result : "+ authResult);
				}
			});
		
		private var handleServerInit:DataHandler = new DataHandler(
			24,
			function(stream:IDataInput):void {
				framebufferWidth = stream.readUnsignedShort();
			    framebufferHeight = stream.readUnsignedShort();
			    bitsPerPixel = stream.readUnsignedByte();
			    depth = stream.readUnsignedByte();
			    bigEndian = stream.readBoolean();
			    trueColour = stream.readBoolean();
			    redMax = stream.readUnsignedShort();
			    greenMax = stream.readUnsignedShort();
			    blueMax = stream.readUnsignedShort();
			    redShift = stream.readUnsignedByte();
			    greenShift = stream.readUnsignedByte();
			    blueShift = stream.readUnsignedByte();
			    stream.readByte();
			    stream.readByte();
			    stream.readByte();
			    handleDesktopName.bytesNeeded = stream.readInt();
			    
			    //depth-=8; // Temp hack
			    
				bytesPerPixel = (bitsPerPixel+7)/8;
				bytesPerPixelDepth = (depth+7)/8;
				
				redMask = redMax << redShift;
				greenMask = greenMax << greenShift;
				blueMask = blueMax << blueShift;
				
				redShift = 16 - redShift;
				greenShift = 8 - greenShift;
				blueShift = blueShift;
				
				for (var i:int=128;i>0;i>>=1) {
					if ((redMax & i) == 0) redShift++;
					if ((greenMax & i) == 0) greenShift++;
					if ((blueMax & i) == 0) blueShift++;
				}
				
				logger.log("bytesPerPixel : "+bytesPerPixel);
				logger.log("bitsPerPixel : "+bitsPerPixel);
				logger.log("depth : "+depth);
				logger.log("trueColour : "+trueColour);
				logger.log("bigEndian : "+bigEndian);
				
				logger.log("redMask : "+redMask.toString(2));
				logger.log("greenMask : "+greenMask.toString(2));
				logger.log("blueMask : "+blueMask.toString(2));
				
				logger.log("redShift : "+redShift);
				logger.log("greenShift : "+greenShift);
				logger.log("blueShift : "+blueShift);
				
				newImageData = new BitmapData(framebufferWidth,framebufferHeight,false,0xFF000000);
				//imageData = new BitmapData(framebufferWidth,framebufferHeight,false,0xFF000000);
				//onFrameBufferUpdate(newImageData);
				//image.bitmapData = imageData;
				
				/*width = framebufferWidth;
				height = framebufferHeight;*/
			});
			
		private var handleDesktopName:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				desktopName = stream.readUTFBytes(handleDesktopName.bytesNeeded);
				onServerInit(desktopName,newImageData);
				//output.text+="Desktop Name : "+desktopName+"\n";
			});
		
		private var handleServerMessage:DataHandler = new DataHandler(
			1,
			function(stream:IDataInput):void {
				var messageType:int = stream.readUnsignedByte();
				//output.text+="messageType : "+messageType+"\n";
				
				switch (messageType) {
					case FramebufferUpdate:
						rfbStack.push(handleFramebufferUpdate);
						break;
					case Bell:
						break;
					case ServerCutText:
						rfbStack.push(handleServerCutText);
						break;
					default :
						throw new Error("Unsuported message type : "+ messageType);
				}
				
				rfbStack.push(handleServerMessage);
			});
			
		private var handleServerCutText:DataHandler = new DataHandler(
			4,
			function(stream:IDataInput):void {
				stream.readByte();
				stream.readByte();
				stream.readByte();
				
				var textSize:int = stream.readUnsignedInt();
				handleServerCutTextData.bytesNeeded = textSize;
				
				rfbStack.unshift(handleServerCutTextData);
			});
		
		private var handleServerCutTextData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				var remoteText:String = stream.readUTFBytes(handleServerCutTextData.bytesNeeded);
				logger.log("remote text : "+remoteText);
			});
		
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
					newImageData.lock();
					rfbStack.unshift(handleFramebufferUpdateRect);
				}
			});
		
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
				if (updateRectEncoding == EncodingLastRect) {
	    			onFrameBufferUpdate();
	    			//onFrameBufferUpdate(newImageData);
					//tmp = imageData;
					//imageData = newImageData;
					//newImageData = tmp;
					newImageData.unlock();
					pause(stream);
					fvnc.callLater(resume);
					return;
				}
				if (updateNRects>0) {
					rfbStack.unshift(handleFramebufferUpdateRect);
				}
	    		
	    		switch (updateRectEncoding) {
	    			case EncodingRaw :
						//output.text+="EncodingTight\n";
						encodingRaw.bytesNeeded = bytesPerPixel*updateRectW*updateRectH;
	    				rfbStack.unshift(encodingRaw);
	    				break;
	    			case EncodingCopyRect :
						//output.text+="EncodingCopyRect\n";
	    				rfbStack.unshift(encodingCopyRect);
	    				break;
	    			case EncodingTight :
						//logger.log("EncodingTight");
	    				rfbStack.unshift(encodingTight);
	    				break;
			   		case EncodingXCursor :
	    				throw new Error("Unsuported encoding : EncodingXCursor");
	    				break;
			   		case EncodingRichCursor :
			   			encodingRichCursor.bytesNeeded =  bytesPerPixel*updateRectW*updateRectH + int((updateRectW+7) / 8)*updateRectH;
			   			rfbStack.unshift(encodingRichCursor);
	    				break;
			   		case EncodingPointerPos :
			   			rfbStack.unshift(encodingCursorPos);
	    				break;
			   		case EncodingNewFBSize :
	    				throw new Error("Unsuported encoding : EncodingNewFBSize");
	    				break;
	    			default :
	    				throw new Error("Unsuported encoding : "+ updateRectEncoding.toString(16));
	    		}
	    		
	    		if (updateNRects == 0) {
	    			onFrameBufferUpdate();
					//tmp = imageData;
					//imageData = newImageData;
					//newImageData = tmp;
					newImageData.unlock();
					pause(stream);
					fvnc.callLater(resume);
	    		}
			});
		
		public function pause(stream:IDataInput):void {
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
		}
			
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
						output[writePos++] = (color & blueMax) << blueShift;
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
						(color & blueMax) << blueShift;
				
				//logger.log(color.toString(16));
			} else {
				throw new Error("Indexed color ");
			}
			return color;
		}
		
		public function writeEncodings(socket:Socket, encodings:Array):void {
			socket.writeByte(SetEncodings);
			socket.writeByte( 0 );
			socket.writeShort( encodings.length );
			for (var i:int=0 ; i < encodings.length ; i++) {
				socket.writeInt(encodings[i]);
			}
			socket.flush();
		}
		
		public function writeFrameBufferUpdate(socket:Socket, updateOnly:Boolean = true, x:int = 0, y:int = 0, width:int = -1, height:int = -1):void {
			socket.writeByte(FramebufferUpdateRequest);
			socket.writeByte(updateOnly ? 1 : 0);
			socket.writeShort(x);
			socket.writeShort(y);
			socket.writeShort(width==-1 ? framebufferWidth :width);
			socket.writeShort(height==-1 ? framebufferHeight : height);
			socket.flush();
		}
		
		public function writeSetPixelFormat(socket:Socket, pixelFormat:Object):void {
			socket.writeByte(SetPixelFormat);
			
			socket.writeByte(0);
			socket.writeByte(0);
			socket.writeByte(0);
			
			socket.writeByte(pixelFormat.bitsPerPixel);
			socket.writeByte(pixelFormat.depth);
			socket.writeByte(pixelFormat.bigEndian ? 1 : 0);
			socket.writeByte(pixelFormat.trueColour ? 1 : 0);
			socket.writeShort(pixelFormat.redMax);
			socket.writeShort(pixelFormat.greenMax);
			socket.writeShort(pixelFormat.blueMax);
			socket.writeByte(pixelFormat.redShift);
			socket.writeByte(pixelFormat.greenShift);
			socket.writeByte(pixelFormat.blueShift);
			
			socket.writeByte(0);
			socket.writeByte(0);
			socket.writeByte(0);
			socket.flush();
			
			trueColour = pixelFormat.trueColour;
			bigEndian = pixelFormat.bigEndian;
			depth = pixelFormat.depth;
			bitsPerPixel = pixelFormat.bitsPerPixel;
			bytesPerPixel = (bitsPerPixel+7)/8;
			bytesPerPixelDepth = (depth+7)/8;
				
			redMask = pixelFormat.redMax << pixelFormat.redShift;
			greenMask = pixelFormat.greenMax << pixelFormat.greenShift;
			blueMask = pixelFormat.blueMax << pixelFormat.blueShift;
			
			redShift = 16 - pixelFormat.redShift;
			greenShift = 8 - pixelFormat.greenShift;
			blueShift = pixelFormat.blueShift;
			
			for (var i:int=128;i>0;i>>=1) {
				if ((pixelFormat.redMax & i) == 0) redShift++;
				if ((pixelFormat.greenMax & i) == 0) greenShift++;
				if ((pixelFormat.blueMax & i) == 0) blueShift++;
			}
			
			logger.log("bytesPerPixel : "+bytesPerPixel);
			logger.log("bitsPerPixel : "+bitsPerPixel);
			logger.log("depth : "+depth);
			logger.log("trueColour : "+trueColour);
			logger.log("bigEndian : "+bigEndian);
			
			logger.log("redMask : "+redMask.toString(2));
			logger.log("greenMask : "+greenMask.toString(2));
			logger.log("blueMask : "+blueMask.toString(2));
			
			logger.log("redShift : "+redShift);
			logger.log("greenShift : "+greenShift);
			logger.log("blueShift : "+blueShift);
		}
		
		/* handles pointer events
		* Right click is emulated with CRT
		*/
		public function writePointerEvent(socket:Socket, event:MouseEvent, emulateRightButton:Boolean):void {
			var pointerMask:int;
			var mask2:int = 2;
			var mask3:int = 4;
			
			/*if ( event.delta < 0 ) {
				pointerMask |= 0x10;
			}
			else if ( event.delta > 0 ) {
				pointerMask |= 0x04;
			}*/
			
			/*if (event.ctrlKey && !emulateRightButton) {
				writeKeyEvent(socket,0xFFE3,true);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,true);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,true);
			}*/
			if (event.buttonDown) {
				if (emulateRightButton && event.ctrlKey) {
					pointerMask |= 0x04;
				} else {
					pointerMask |= 0x01;
				}
			}
			
			socket.writeByte(PointerEvent);
			socket.writeByte(pointerMask);
			socket.writeShort(event.localX);
			socket.writeShort(event.localY);
			
			/*if (event.ctrlKey && !emulateRightButton) {
				writeKeyEvent(socket,0xFFE3,false);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,false);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,false);
			}*/
			
			socket.flush();
		}
		
		private function writeKeyEvent(socket:Socket, keyCode:uint, pushed:Boolean):void {
			socket.writeByte(KeyboardEvent);
			socket.writeByte(pushed ? 1 : 0);
			socket.writeByte(0);
			socket.writeByte(0);
			socket.writeUnsignedInt(keyCode);
		}
		
		/* handles keys events
		*	this is full of bugs
		*/
		private var crtDown:Boolean = false;
		public function writeKeyboardEvent(socket:Socket, event:flash.events.KeyboardEvent):void {
			/*if (event.keyCode == Keyboard.SHIFT || 
				event.keyCode == Keyboard.CONTROL) {
					return;
				}
				
			if (event.ctrlKey) {
				writeKeyEvent(socket,0xFFE3,true);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,true);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,true);
			}*/
			
			var keysym:uint;
			
			switch ( event.keyCode ) {
				case Keyboard.BACKSPACE : keysym = 0xFF08; break;
				case Keyboard.TAB       : keysym = 0xFF09; break;
				case Keyboard.ENTER     : keysym = 0xFF0D; break;
				case Keyboard.ESCAPE    : keysym = 0xFF1B; break;
				case Keyboard.INSERT    : keysym = 0xFF63; break;
				case Keyboard.DELETE    : keysym = 0xFFFF; break;
				case Keyboard.HOME      : keysym = 0xFF50; break;
				case Keyboard.END       : keysym = 0xFF57; break;
				case Keyboard.PAGE_UP   : keysym = 0xFF55; break;
				case Keyboard.PAGE_DOWN : keysym = 0xFF56; break;
				case Keyboard.LEFT   	: keysym = 0xFF51; break;
				case Keyboard.UP   		: keysym = 0xFF52; break;
				case Keyboard.RIGHT   	: keysym = 0xFF53; break;
				case Keyboard.DOWN   	: keysym = 0xFF54; break;
				case Keyboard.F1   		: keysym = 0xFFBE; break;
				case Keyboard.F2   		: keysym = 0xFFBF; break;
				case Keyboard.F3   		: keysym = 0xFFC0; break;
				case Keyboard.F4   		: keysym = 0xFFC1; break;
				case Keyboard.F5   		: keysym = 0xFFC2; break;
				case Keyboard.F6   		: keysym = 0xFFC3; break;
				case Keyboard.F7   		: keysym = 0xFFC4; break;
				case Keyboard.F8   		: keysym = 0xFFC5; break;
				case Keyboard.F9   		: keysym = 0xFFC6; break;
				case Keyboard.F10  		: keysym = 0xFFC7; break;
				case Keyboard.F11  		: keysym = 0xFFC8; break;
				case Keyboard.F12  		: keysym = 0xFFC9; break;
				case Keyboard.CONTROL : keysym = 0xFFE3;
					crtDown = event.type == flash.events.KeyboardEvent.KEY_DOWN ? true: false;
					break;
				case Keyboard.SHIFT : keysym = 0xFFE1;break;
				default:
					keysym = event.charCode;
			}
			
			if (event.type == flash.events.KeyboardEvent.KEY_UP && crtDown)  {
				writeKeyEvent(socket,keysym,true);
				writeKeyEvent(socket,keysym,false);
				writeKeyEvent(socket,0xFFE3,false);
				crtDown = false;
			} else{
				writeKeyEvent(socket,keysym,event.type == flash.events.KeyboardEvent.KEY_DOWN ? true: false);
			}
			
			/*if (event.ctrlKey) {
				writeKeyEvent(socket,0xFFE3,false);
			}
			if (event.altKey) {
				writeKeyEvent(socket,0xFFE1,false);
			}
			if (event.shiftKey) {
				writeKeyEvent(socket,0xFFE9,false);
			}*/
			
			socket.flush();
		}
		
		public function updateImage(rect:Rectangle, data:ByteArray):void {
			data.position = 0;
			newImageData.setPixels(rect,data);
		}
		
		public function updateImageFillRect(rect:Rectangle, color:uint):void {
	  		newImageData.fillRect(rect,color);
		}	
		
		public function copyImage(src:Point, dst:Rectangle):void {
			var copyRect:ByteArray =  newImageData.getPixels(
				new Rectangle(src.x,src.y,dst.width,dst.height));
		    copyRect.position = 0;
		    newImageData.setPixels(dst,copyRect);
		}
		
		public function updateCursorShape(x:int, y:int, shape:BitmapData):void {
			onCursorShapeUpdate(x,y,shape);
		}
		
		public function updateCursorPosition(x:int, y:int):void {
			onCursorPositionUpdate(x,y);
		}		    
	}
}