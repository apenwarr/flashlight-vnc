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
	Support of tight encoding
*/

package com.wizhelp.flashlight.codec
{
	import com.wizhelp.flashlight.rfb.RFBReader;
	import com.wizhelp.flashlight.thread.DataHandler;
	import com.wizhelp.flashlight.vnc.VNCHandler;
	import com.wizhelp.flashlight.zlib.InflaterFZlib;
	import com.wizhelp.flashlight.zlib.InflaterFlash10;
	import com.wizhelp.utils.BufferPool;
	import com.wizhelp.utils.Thread;
	import com.wizhelp.utils.ThreadFunction;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	
	public class CodecTight extends DataHandler
	{
		private static var logger:ILogger = Log.getLogger('com.wizhelp.flashlight.codec.CodecTight');
		
		public static const TightMinToCompress:int  = 12;
		public static const TightExplicitFilter:int = 0x04;
		public static const TightFill:int           = 0x08;
		public static const TightJpeg:int           = 0x09;
		public static const TightMaxSubencoding:int = 0x09;
		public static const TightFilterCopy:int     = 0x00;
		public static const TightFilterPalette:int  = 0x01;
		public static const TightFilterGradient:int = 0x02;
    
		private var tightInflaters:Array = new Array(4);
		private var numColors:int;
		private var rowSize:int;
		private var tightPalette:Array = new Array(256);
		private var useGradient:Boolean;
		private var tightCode:int; 
		private var tightDataSize:int;
		private var tightZlibDataSize:int;
		private var jpgLoader:Loader = new Loader();
		private var bytesPerPixel:int;
		private var useFlash10Optimization:Boolean = false;
		
		private var rfbReader:RFBReader;
		private var vnc:VNCHandler;
		private var async:Boolean;
		
		public function CodecTight(vnc:VNCHandler, rfbReader:RFBReader, async:Boolean) {
			super(
				1,
					function(stream:IDataInput):void {
						tightCode = stream.readUnsignedByte();
						bytesPerPixel = rfbReader.bytesPerPixelDepth;
						
						// Flush zlib streams if we are told by the server to do so.
						for (var i:int=0; i < 4; i++) {
							if (tightCode & 1 != 0 && tightInflaters[i] != null) {
								tightInflaters[i] = null;
							}
							tightCode >>= 1;
						}
						
						switch (tightCode) {
							case TightJpeg :
								//logger.debug("TightJpeg");
								rfbReader.rfbStack.unshift(
									handleTightJpegLen,
									handleTightJpegData);
								break;
							case TightFill :
								//logger.debug("TightFill");
								handleTightFill.bytesNeeded = bytesPerPixel;
								rfbReader.rfbStack.unshift(handleTightFill);
								break;
							default :
								//logger.debug("Default");
								numColors = 0;
								useGradient = false;
								rowSize = rfbReader.updateRectW;
								rfbReader.rfbStack.unshift(handleTightData);
								if (tightCode & TightExplicitFilter) {
									//logger.debug("TightExplicitFilter");
									rfbReader.rfbStack.unshift(handleTightFilter);
								}
						}
						//logger.debug("<< CodecTight");
					},
					this);
				
			this.rfbReader = rfbReader;
			this.vnc = vnc;
			this.useFlash10Optimization = String(Capabilities.version.split(' ')[1]).substr(0,2) == "10";
			this.async = async;
		}
		
		private var handleTightData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				//logger.debug(">> handleTightData");
				
				if (numColors == 0)
					rowSize *= bytesPerPixel;
				tightDataSize = rowSize * rfbReader.updateRectH;
				if (tightDataSize < TightMinToCompress) {
					if (numColors!=0) {
						handleTightIndexedData.bytesNeeded = tightDataSize;
						rfbReader.rfbStack.unshift(handleTightIndexedData);
					} else if (useGradient) {
						handleTightGradientData.bytesNeeded = tightDataSize;
						rfbReader.rfbStack.unshift(handleTightGradientData);
					} else {
						handleTightRawData.bytesNeeded = rfbReader.updateRectH*rfbReader.updateRectW*rfbReader.bytesPerPixel;
						rfbReader.rfbStack.unshift(handleTightRawData);
					}
				} else {
					rfbReader.rfbStack.unshift(
						handleTightZlibLen,
						handleTightZlibData);
				}
				
				//logger.debug("<< handleTightData");
			},
			this);
		
		/* handle Tight data encoded with gradient filter
		*  very slow but seems to be used only if Jpeg is disable
		*  TODO: optimize it with BitmapData.applyFilter()
		*/
		private var handleTightGradientData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				//logger.timeStart('handleTightGradientData');
				
				var rawDataBuffer:ByteArray = BufferPool.getDataBuffer(tightDataSize);
				var pixelsBuffer:ByteArray = BufferPool.getDataBuffer(4*rfbReader.updateRectW*rfbReader.updateRectH);
				
				stream.readBytes(rawDataBuffer,0,tightDataSize);
				
				var tmpRow:Array;
				var prevRowR:ByteArray = new Array();
				var prevRowG:ByteArray = new Array();
				var prevRowB:ByteArray = new Array();
				var thisRowR:Array = new Array();
				var thisRowG:Array = new Array();
				var thisRowB:Array = new Array();
				var x:int=0;
				var i:int, j:int;
				var readPos:int = 0;
				var writePos:int = 0;
				var bytesPerPixel:int = rfbReader.bytesPerPixel;
				var length:int = rfbReader.updateRectW*rfbReader.updateRectH;
				var useDepth:Boolean = rfbReader.bytesPerPixel != rfbReader.bytesPerPixelDepth;
				
				for (j=-1;j<rfbReader.updateRectW;j++) {
					prevRowR[j] = 0;
					prevRowG[j] = 0;
					prevRowB[j] = 0;
					thisRowR[j] = 0;
					thisRowG[j] = 0;
					thisRowB[j] = 0;
				}
				
				for (j=0;j<length;j++) {
					var color:uint=0;
					var shift:int = 0;
					
					if (!useDepth) {
						if (!rfbReader.bigEndian) {
							for (i=0;i<bytesPerPixel;i++) {
								color |= rawDataBuffer[readPos++] <<shift;
								shift+=8;
							}
						} else {
							for (i=0;i<bytesPerPixel;i++) {
								color <<= 8;
								color |= rawDataBuffer[readPos++];
							}
						}
					} else {
						if (!rfbReader.bigEndian) {
							for (i=0;i<rfbReader.bytesPerPixelDepth;i++) {
								color <<= 8;
								color |= rawDataBuffer[readPos++];
							}
						} else {
							for (i=0;i<rfbReader.bytesPerPixelDepth;i++) {
								color |= rawDataBuffer[readPos++] <<shift;
								shift+=8;
							}
						}
					}
		
					thisRowR[x] = prevRowR[x] - prevRowR[x-1] + thisRowR[x-1];
					thisRowG[x] = prevRowG[x] - prevRowG[x-1] + thisRowG[x-1];
					thisRowB[x] = prevRowB[x] - prevRowB[x-1] + thisRowB[x-1];
					
					if (thisRowR[x] < 0) thisRowR[x] = 0;
					if (thisRowG[x] < 0) thisRowG[x] = 0;
					if (thisRowB[x] < 0) thisRowB[x] = 0;
					
					if (thisRowR[x] > rfbReader.redMask) thisRowR[x] = rfbReader.redMask;
					if (thisRowG[x] > rfbReader.greenMask) thisRowG[x] = rfbReader.greenMask;
					if (thisRowB[x] > rfbReader.blueMask) thisRowB[x] = rfbReader.blueMask;
					
					thisRowR[x] = ((thisRowR[x] + color) & rfbReader.redMask) ;
					thisRowG[x] = ((thisRowG[x] + color) & rfbReader.greenMask) ;
					thisRowB[x] = ((thisRowB[x] + color) & rfbReader.blueMask) ;
						
					pixelsBuffer[writePos++] = 0xFF;
					pixelsBuffer[writePos++] = thisRowR[x] >> (16-rfbReader.redShift);
					pixelsBuffer[writePos++] = thisRowG[x] >> (8 - rfbReader.greenShift);
					pixelsBuffer[writePos++] = thisRowB[x] << rfbReader.blueShift;
					
					x++;
					if (x == rfbReader.updateRectW) {
						x = 0;
						tmpRow = prevRowR;
						prevRowR = thisRowR;
						thisRowR = tmpRow;
						
						tmpRow = prevRowG;
						prevRowG = thisRowG;
						thisRowG = tmpRow;
						
						tmpRow = prevRowB;
						prevRowB = thisRowB;
						thisRowB = tmpRow;
					}
				}
				
				BufferPool.releaseDataBuffer(rawDataBuffer);
				
				vnc.handleUpdateImage(
					rfbReader.updateRect,
					pixelsBuffer);
			
				/*rfbReader.readPixels(
					rawDataBuffer,
					pixelsBuffer,
					rfbReader.updateRectW*rfbReader.updateRectH,
					rfbReader.bytesPerPixel != rfbReader.bytesPerPixelDepth);
					
				BufferPool.releaseDataBuffer(rawDataBuffer);
					
				var index:int = 0;
				var x:int, y:int, c:int;
				var rowOffset:int = rfbReader.updateRectW*4;*/
				
				/*index+=4;
				for (x=1; x<rfbReader.updateRectW; x++) {
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-4];
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-4];
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-4];
					index++;
				}*/
				/*for (y=0; y<rfbReader.updateRectH; y++) {
					index++;
					pixelsBuffer[index] += index-rowOffset>0 ? pixelsBuffer[index-rowOffset] : 0;
					index++;
					pixelsBuffer[index] += index-rowOffset>0 ? pixelsBuffer[index-rowOffset] : 0;
					index++;
					pixelsBuffer[index] += index-rowOffset>0 ? pixelsBuffer[index-rowOffset] : 0;
					index++;
					for (x=1; x<rfbReader.updateRectW; x++) {
						index++;
						for (c=0; c<3; c++) {
							var est:int = index-rowOffset>0 ? pixelsBuffer[index-rowOffset] - pixelsBuffer[index-rowOffset-4] + pixelsBuffer[index-4] : pixelsBuffer[index-4];*/
								
							/*if (est > 0xFF) {
								est = 0xFF;
							} else if (est < 0) {
								est = 0;
							}*/
							//pixelsBuffer[index++] = (pixelsBuffer[index] + est) & 0xFF;
							//pixelsBuffer[index++] = 0;
						/*}
					}
				}
				
				vnc.handleUpdateImage(
					rfbReader.updateRect,
					pixelsBuffer);*/
					
				/*rfbReader.readPixels(
					rawDataBuffer,
					pixelsBuffer,
					rfbReader.updateRectW*rfbReader.updateRectH,
					rfbReader.bytesPerPixel != rfbReader.bytesPerPixelDepth);
					
				BufferPool.releaseDataBuffer(rawDataBuffer);
					
				var index:int = 0;
				var x:int, y:int, c:int;
				
				index+=4;
				for (x=1; x<rfbReader.updateRectW; x++) {
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-4];
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-4];
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-4];
					index++;
				}
				for (y=1; y<rfbReader.updateRectH; y++) {
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-rfbReader.updateRectW*4];
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-rfbReader.updateRectW*4];
					index++;
					pixelsBuffer[index] += pixelsBuffer[index-rfbReader.updateRectW*4];
					index++;
					for (x=1; x<rfbReader.updateRectW; x++) {
						index++;
						for (c=0; c<3; c++) {
							var est:int = pixelsBuffer[index-rfbReader.updateRectW*4]
								+ pixelsBuffer[index-4]
								- pixelsBuffer[index-rfbReader.updateRectW*4-4];
							if (est > 0xFF) {
								est = 0xFF;
							} else if (est < 0x00) {
								est = 0x00;
							}
							pixelsBuffer[index++] += est;
						}
					}
				}
				
				vnc.handleUpdateImage(
					rfbReader.updateRect,
					pixelsBuffer);*/
				
				/*var dx:int, dy:int, c:int;
				var prevRow:ByteArray = new ByteArray();
				prevRow.length = rfbReader.updateRectW;
				var thisRow:ByteArray = new ByteArray();
				thisRow.length = rfbReader.updateRectW;
				var pix:ByteArray = new ByteArray();
				pix.length = rfbReader.bytesPerPixel;
				var est:Array = new Array(rfbReader.bytesPerPixel);
				var tmp:ByteArray;
				
				for (c=0;c<rfbReader.updateRectW*rfbReader.bytesPerPixel;++c) {
					prevRow[c] = 0;
				}
		
				for (dy = 0; dy < rfbReader.updateRectH; dy++) {
		
					// First pixel in a row 
					for (c = 0; c < rfbReader.bytesPerPixel; c++) {
						pix[c] = prevRow[c] + rfb.rawDataBuffer[dy * rfb.updateRectW * rfb.bytesPerPixel + c];
						thisRow[c] = pix[c];
					}
					rfb.newImageData.setPixel(rfb.updateRectX,rfb.updateRectY+dy,
							pix[2] << 16 | pix[1] << 8 | pix[0] );
		
					// Remaining pixels of a row 
					for (dx = 1; dx < rfb.updateRectW; dx++) {
						for (c = 0; c < rfb.bytesPerPixel; c++) {
							est[c] =
									prevRow[dx * rfb.bytesPerPixel + c] 
									+ pix[c]
									- prevRow[(dx - 1) * rfb.bytesPerPixel + c] ;
							if (est[c] > 0xFF) {
								est[c] = 0xFF;
							} else if (est[c] < 0x00) {
								est[c] = 0x00;
							}
							pix[c] = est[c] + rfb.rawDataBuffer[(dy * rfb.updateRectW + dx) * rfb.bytesPerPixel + c];
							thisRow[dx * rfb.bytesPerPixel + c] = pix[c];
						}
						rfb.newImageData.setPixel(rfb.updateRectX+dx,rfb.updateRectY+dy,
							pix[2] << 16 | pix[1] << 8 | pix[0] );
					}
		
					tmp = thisRow;
					thisRow = prevRow;
					prevRow = tmp;
				}*/
		
		
				/*var thisRow:ByteArray = new ByteArray();
				thisRow.length = rfb.updateRectW * 3;
				var previousRow:ByteArray = new ByteArray();
				previousRow.length = rfb.updateRectW * 3;
				var tmp:ByteArray;
				var color:uint;
				var pix:ByteArray = new ByteArray();
				pix.length = 3;
				var est:Array = new Array(3);
				var readPos:int = 0;
				var i:int, j:int;
				
				for (i=0;i<rfb.updateRectW*3;++i) {
					previousRow[i] = 0;
				}

				for (var y:int = rfb.updateRectY ; y < rfb.updateRectY + rfb.updateRectH ; ++y) {
					var first:Boolean = true;
					j = 0;
					for (var x:int = rfb.updateRectX ; x < rfb.updateRectX + rfb.updateRectW ; ++x) {
						if (first) {
							for (i=0;i<3;++i) {
								pix[i] = previousRow[i] + rfb.rawDataBuffer[readPos++];
								thisRow[i] = pix[i];
							}
							first = false;
						} else {
							for (i=0;i<3;++i) {
								est[i] = previousRow[3*j+i] + pix[i] - previousRow[3*(j-1)+i];
								if (est[i] <0) {est[i] = 0;}
								if (est[i] >255) {est[i] = 255;}
								pix[i] = est[i] + rfb.rawDataBuffer[readPos++];
								thisRow[3*j+i] = est[i];
							}
						}
						color = 0xFF000000 | (pix[0] <<16) | (pix[1] << 8) | pix[2];
						rfb.newImageData.setPixel(x,y,color);
						j++;
					}
					tmp = thisRow;
					thisRow = previousRow;
					previousRow = tmp;
				}*/
					
				//logger.timeEnd('handleTightGradientData');
			},
			this);
		
		/* Handle tight data encoded in tight raw format
		*/
		private var handleTightRawData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				//logger.timeStart('handleTightRawData');
				
				var rawDataBuffer:ByteArray = BufferPool.getDataBuffer(tightDataSize);
				var pixelsBuffer:ByteArray = BufferPool.getDataBuffer(4*rfbReader.updateRectW*rfbReader.updateRectH);
				
				stream.readBytes(rawDataBuffer,0,tightDataSize);
				rawDataBuffer.position = 0;
				
				//readPixels2(rawDataBuffer,newImageData,updateRectW*updateRectH);
				rfbReader.readPixels(
					rawDataBuffer,
					pixelsBuffer,
					rfbReader.updateRectW*rfbReader.updateRectH,
					rfbReader.bytesPerPixel != rfbReader.bytesPerPixelDepth);
				
				BufferPool.releaseDataBuffer(rawDataBuffer);
				
				vnc.handleUpdateImage(
					rfbReader.updateRect,
					pixelsBuffer);
					
				//logger.timeEnd('handleTightRawData');
			},
			this);
		
		/* Handle tight data encoded in tight raw format
		*/
		private var handleTightIndexedData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				//logger.timeStart('handleTightIndexedData2');
				
				var x:int;
				var y:int;
				var color:int;
				var dataPos:int=0;
				var pixelsBuffer:ByteArray;
				var rawDataBuffer:ByteArray;
				
				//output.text+="Indexed color data \n";
				if (numColors == 2) {
					// Only 2 colors, pixels are packed
					// TODO optimze this with BitmapData.paletteMap
					var data:int;
					var shift:int;
				
					rawDataBuffer = BufferPool.getDataBuffer(tightDataSize);
					pixelsBuffer = BufferPool.getDataBuffer(4*rfbReader.updateRectW*rfbReader.updateRectH);
					
					var index:int = 0;
					
					stream.readBytes(rawDataBuffer,0,tightDataSize);
					
					BufferPool.releaseDataBuffer(rawDataBuffer);
					
					for (y=rfbReader.updateRectY;y<rfbReader.updateRectY+rfbReader.updateRectH;y++) {
						shift = 8;
						for (x=rfbReader.updateRectX;x<rfbReader.updateRectX+rfbReader.updateRectW;x++) {
							if (shift == 8) {
								shift = 0;
								data = rawDataBuffer[dataPos++];
								//output.text+="data "+data.toString(2)+"\n";
							} else {
								data = data << 1;
							}
							
							//output.text+=x+" "+y+" "+tightPalette[data & 0x80]+"\n";
							color = tightPalette[(data >> 7) & 0x01];
							pixelsBuffer[index++] = 0xFF;
							pixelsBuffer[index++] = color>>16;
							pixelsBuffer[index++] = color>>8;
							pixelsBuffer[index++] = color;
							
							shift++;
						}
					}
					
					vnc.handleUpdateImage(
						rfbReader.updateRect,
						pixelsBuffer);
					
					//logger.timeEnd('handleTightIndexedData2');
				} else {
					// Optimized decompression of a block of indexed pixels
					// TODO create a generic method to do this on RFB.as and use it
				
					//logger.timeStart('handleTightIndexedDataP1');
					
					var i:int = 0;
					var nullPalette:Array = new Array(256);
					for (i=0;i<256;i++) {
						nullPalette[i]=0;
					}
					
					var maxBitmapHeigth:int = 1500;
					var dataSize:int = tightDataSize;
					var emptyFills:int = tightDataSize % 4 == 0 ? 0 : 4 - (tightDataSize % 4);
					
					var tmpBitmapHeigth:int = int((tightDataSize+3) / 4);
					var tmpBitmapWidth:int = 1;
					if (tmpBitmapHeigth > maxBitmapHeigth) {
						emptyFills += tmpBitmapHeigth % maxBitmapHeigth == 0 ? 0 : (maxBitmapHeigth - (tmpBitmapHeigth % maxBitmapHeigth)) * 4;
						tmpBitmapWidth = int((tmpBitmapHeigth+maxBitmapHeigth-1) / maxBitmapHeigth);
						tmpBitmapHeigth = maxBitmapHeigth;
					}
					
					rawDataBuffer = BufferPool.getDataBuffer(tightDataSize+emptyFills);
					
					stream.readBytes(rawDataBuffer,0,tightDataSize);
					rawDataBuffer.position = 0;
					
					/*logger.log(rfb.updateRectX+" "+rfb.updateRectY+" "+rfb.updateRectW+" "+rfb.updateRectH);
					logger.log(tightDataSize+" ");
					logger.log(tmpBitmapWidth+" "+tmpBitmapHeigth);
					logger.log(rfb.rawDataBuffer.length+" ");*/
					
					var tmpBitmapDataIndexed:BitmapData = new BitmapData(tmpBitmapWidth,tmpBitmapHeigth,false,0xFFFFFFFF);
					var tmpBitmapDataIndexedAlpha:BitmapData = new BitmapData(tmpBitmapWidth,tmpBitmapHeigth,true,0xFFFFFFFF);
					var tmpBitmapDataFull:BitmapData = new BitmapData(tmpBitmapWidth*4,tmpBitmapHeigth,false,0xFFFFFFFF);
					
					tmpBitmapDataIndexed.setPixels(tmpBitmapDataIndexed.rect,rawDataBuffer);
					rawDataBuffer.position = 0;
					tmpBitmapDataIndexedAlpha.setPixels(tmpBitmapDataIndexed.rect,rawDataBuffer);
					
					for (i = 0;i<tmpBitmapWidth;i++) {
						tmpBitmapDataFull.paletteMap(tmpBitmapDataIndexedAlpha,
							new Rectangle(i,0,1,tmpBitmapHeigth),
							new Point(i*4,0),
							nullPalette,
							nullPalette,
							nullPalette,
							tightPalette);
							
						tmpBitmapDataFull.paletteMap(tmpBitmapDataIndexed,
							new Rectangle(i,0,1,tmpBitmapHeigth),
							new Point(i*4+1,0),
							tightPalette,
							nullPalette,
							nullPalette,
							nullPalette);
						
						tmpBitmapDataFull.paletteMap(tmpBitmapDataIndexed,
							new Rectangle(i,0,1,tmpBitmapHeigth),
							new Point(i*4+2,0),
							nullPalette,
							tightPalette,
							nullPalette,
							nullPalette);
						
						tmpBitmapDataFull.paletteMap(tmpBitmapDataIndexed,
							new Rectangle(i,0,1,tmpBitmapHeigth),
							new Point(i*4+3,0),
							nullPalette,
							nullPalette,
							tightPalette,
							nullPalette);
					}
					
					pixelsBuffer = tmpBitmapDataFull.getPixels(tmpBitmapDataFull.rect);
					pixelsBuffer.position = 0;
					vnc.handleUpdateImage(
						rfbReader.updateRect,
						pixelsBuffer);
					/*var colorIndex:int;
					var maxX:int = rfb.updateRectX +rfb.updateRectW;
					var size:int = rfb.updateRectW*rfb.updateRectH;
					var pixBuffer:ByteArray = rfb.pixelsBuffer;
					pixBuffer.position = 0;
					y = rfb.updateRectY;
					x = rfb.updateRectX;
					logger.timeStart('handleTightIndexedDataP1');
					
					var bufPos:int=0;
					for (var i:int=0 ; i<size;i++) {
						
						colorIndex = rfb.rawDataBuffer[i];
						color = tightPalette[colorIndex];
						rfb.newImageData.setPixel(x,y,color);
						
						x++;
						if (x  == maxX) {
							x = rfb.updateRectX;
							y++;
						}*/
						
						/*colorIndex = rfb.rawDataBuffer[i];
						color = tightPalette[colorIndex];
						//pixBuffer.writeUnsignedInt(color);
						pixBuffer[bufPos++] = 0xFF;
						pixBuffer[bufPos++] = color>>16;
						pixBuffer[bufPos++] = color>>8;
						pixBuffer[bufPos++] = color;*/
						
						/*pixBuffer.writeByte(0xFF);
						pixBuffer.writeByte(0xAA);
						pixBuffer.writeByte(0xFF);
						pixBuffer.writeByte(0x44);*/
						
						//pixBuffer.writeUnsignedInt(0xFF457889);
						
						/*rfb.pixelsBuffer[pixelPos++]=0xFF;
						rfb.pixelsBuffer[pixelPos++]=0;
						rfb.pixelsBuffer[pixelPos++]=0;
						rfb.pixelsBuffer[pixelPos++]=6;*/
					//}
					
					//pixBuffer.position = 0;
					
					/*for (y=rfb.updateRectY;y<rfb.updateRectY+rfb.updateRectH;y++) {
						for (x=rfb.updateRectX;x<rfb.updateRectX+rfb.updateRectW;x++) {
							colorIndex = rfb.rawDataBuffer[i++];
							color = tightPalette[colorIndex];
							//rfb.newImageData.setPixel(x,y,color);
							rfb.pixelsBuffer[pixelPos++]=0xFF;
							rfb.pixelsBuffer[pixelPos++]=0;
							rfb.pixelsBuffer[pixelPos++]=0;
							rfb.pixelsBuffer[pixelPos++]=6;
						}
					}*/
					//logger.timeEnd('handleTightIndexedDataP1');
					
					/*logger.timeStart('handleTightIndexedDataP2');
					
					rfb.newImageData.setPixels(
							new Rectangle(
								rfb.updateRectX,
								rfb.updateRectY,
								rfb.updateRectW,
								rfb.updateRectH),
							rfb.pixelsBuffer);
							
					logger.timeEnd('handleTightIndexedDataP2');*/

				}
			},
			this);	
		
		private var handleTightFilter:DataHandler = new DataHandler(
			1,
			function(stream:IDataInput):void {
				var filterId:int = stream.readUnsignedByte();
				//output.text+="TightFilter : "+filterId+"\n";
				switch (filterId) {
					case TightFilterPalette :
						rfbReader.rfbStack.unshift(handleTightPaletteHeader);
					break;
					case TightFilterGradient :
						//output.text+="TightFilterGradient : "+filterId+"\n";
						useGradient = true;
					break;
					case TightFilterCopy :
						//output.text+="TightFilterCopy : "+filterId+"\n";
					break;
					default :
						throw new Error("Incorrect Tight filter id : "+ filterId);
				}
			},
			this);
		
		private var handleTightPaletteHeader:DataHandler = new DataHandler(
			1,
			function(stream:IDataInput):void {
				numColors = stream.readUnsignedByte()+1;
				//output.text+="TightFilterPalette : "+numColors+"\n";
				handleTightPaletteColors.bytesNeeded = numColors*bytesPerPixel;
				rfbReader.rfbStack.unshift(handleTightPaletteColors);
			},
			this);
		
		private var handleTightPaletteColors:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				for (var i:int=0;i<numColors;i++) {
					tightPalette[i] = rfbReader.readPixel(stream,rfbReader.bytesPerPixel != rfbReader.bytesPerPixelDepth);
				}
				
				if (numColors == 2)
					rowSize = (rfbReader.updateRectW + 7) / 8;
			},
			this);
		
		private var handleTightZlibLen:DataHandler = new DataHandler(
			3,
			function(stream:IDataInput):void {
				tightZlibDataSize = readCompactLen(stream);
				handleTightZlibData.bytesNeeded = tightZlibDataSize;
			},
			this);
		
		
		/* Handle tight data compressed in a Zlib stream
		* TODO : improve Flash 9 support by using pseudo-multithreading
		*				function has to be split in small ones taking less than 20ms each
		*/
		private var inflater:*;
		private var handleTightZlibData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				//logger.timeStart('handleTightZlibData');
				//logger.debug('>> handleTightZlibData');
				
				var compressedBuffer:ByteArray = BufferPool.getDataBuffer(tightZlibDataSize);
				stream.readBytes(compressedBuffer,0,tightZlibDataSize);
				
				var streamId:int = tightCode & 0x03;
				inflater = tightInflaters[streamId];
				
				if (useFlash10Optimization) {
					if (inflater == null) {
						inflater = new InflaterFlash10();
						tightInflaters[streamId] = inflater;
					}
					
					inflater.inflate(compressedBuffer,tightZlibDataSize, tightDataSize);
					//logger.timeEnd('inflater');
				} else {
					if (inflater == null) {
						inflater = new InflaterFZlib();
						tightInflaters[streamId] = inflater;
					}
					
					inflater.inflateThreaded(compressedBuffer,tightZlibDataSize, tightDataSize);
				}
				
				rfbReader.rfbStack.unshift(processUncompressedData);
				
				//logger.debug('<< handleTightZlibData');
			},
			this);
			
		private var processUncompressedData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				//logger.debug('>> processUncompressedData');
				
				//logger.timeEnd('handleTightZlibData');
					
				//logger.timeStart('handlingTightZlibData');
				if (numColors!=0) {
					handleTightIndexedData.bytesNeeded = tightDataSize;
					handleTightIndexedData.call.apply(handleTightIndexedData.object, [inflater.uncompressedData]);
				} else if (useGradient) {
					handleTightGradientData.bytesNeeded = tightDataSize;
					handleTightGradientData.call.apply(handleTightGradientData.object, [inflater.uncompressedData]);
				} else {
					handleTightRawData.bytesNeeded = rfbReader.updateRectH*rfbReader.updateRectW*rfbReader.bytesPerPixel;
					handleTightRawData.call.apply(handleTightRawData.object, [inflater.uncompressedData]);
				}
				//logger.timeEnd('handlingTightZlibData');
			
				//logger.debug('<< processUncompressedData');
			},
			this);
			
		private var handleTightFill:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				var color:uint = rfbReader.readPixel(stream,rfbReader.bytesPerPixel != rfbReader.bytesPerPixelDepth);
				var rect:Rectangle = new Rectangle(
					rfbReader.updateRectX,
					rfbReader.updateRectY,
					rfbReader.updateRectW,
					rfbReader.updateRectH);
				vnc.handleUpdateImageFillRect(
					rfbReader.updateRect,
					color);
			},
			this);
			
		private var handleTightJpegLen:DataHandler = new DataHandler(
			3,
			function(stream:IDataInput):void {
				handleTightJpegData.bytesNeeded = readCompactLen(stream);
			},
			this);
			
		private var handleTightJpegData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				//logger.timeStart('handleTightJpegData');
				
				var rawDataBuffer:ByteArray = BufferPool.getDataBuffer(tightDataSize);
				
				stream.readBytes(rawDataBuffer,0,handleTightJpegData.bytesNeeded);
				
				if (!async) {
					jpgLoader.loadBytes(rawDataBuffer);
					
					BufferPool.releaseDataBuffer(rawDataBuffer);
					
					Thread.currentThread.stack.unshift(new ThreadFunction(this,handleTightJpegComplete));
					Thread.currentThread.wait(jpgLoader.contentLoaderInfo, Event.COMPLETE);
				} else {
					var loader:Loader = new Loader();
					
					loader.loadBytes(rawDataBuffer);
					
					vnc.handleUpdateImageAsyncJpeg(
						rfbReader.updateRect,
						loader);
				}
			},
			this);		
		
		private function handleTightJpegComplete():void {
			var jpegImage:BitmapData = Bitmap(jpgLoader.content).bitmapData;
				
			vnc.handleUpdateImage(
				rfbReader.updateRect,
				jpegImage.getPixels(jpegImage.rect)
				);
			
			jpgLoader.unload();
			
			//logger.timeEnd('handleTightJpegData');
		}
			
		private function readCompactLen(stream:IDataInput):int {
			var p0:int = stream.readUnsignedByte();
			var len:int = p0 & 0x7F;
			if ((p0 & 0x80) != 0) {
				var p1:int = stream.readUnsignedByte();
				len |= (p1 & 0x7F) << 7;
				if ((p1 & 0x80) != 0) {
					var p2:int = stream.readUnsignedByte();
					len |= (p2 & 0xFF) << 14;
				}
			}
			return len;
		}
	}
}