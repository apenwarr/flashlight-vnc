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

package com.wizhelp.fvnc.codec
{
	import com.wizhelp.fvnc.DataHandler;
	import com.wizhelp.fvnc.Logger;
	import com.wizhelp.fvnc.RFB;
	import com.wizhelp.utils.Inflater;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.utils.IDataInput;
	
	public class CodecTight extends DataHandler
	{
		private var logger:Logger = new Logger(this);
		
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
		private var compressedBuffer:ByteArray = new ByteArray();
		private var uncompressedBuffer:ByteArray = new ByteArray();
		private var bytesPerPixel:int;
		
		private var rfb:RFB;
		
		public function CodecTight(rfb:RFB) {
			super(
				1,
					function(stream:IDataInput):void {
						tightCode = stream.readUnsignedByte();
						bytesPerPixel = rfb.bytesPerPixelDepth;
						
						// Flush zlib streams if we are told by the server to do so.
						for (var i:int=0; i < 4; i++) {
							if (tightCode & 1 != 0 && tightInflaters[i] != null) {
								tightInflaters[i] = null;
							}
							tightCode >>= 1;
						}
						
						switch (tightCode) {
							case TightJpeg :
								//logger.log("TightJpeg");
								rfb.rfbStack.unshift(
									handleTightJpegLen,
									handleTightJpegData);
								break;
							case TightFill :
								//logger.log("TightFill");
								handleTightFill.bytesNeeded = bytesPerPixel;
								rfb.rfbStack.unshift(handleTightFill);
								break;
							default :
								//logger.log("Default");
								numColors = 0;
								useGradient = false;
								rowSize = rfb.updateRectW;
								rfb.rfbStack.unshift(handleTightData);
								if (tightCode & TightExplicitFilter) {
									rfb.rfbStack.unshift(handleTightFilter);
								}
						}
					});
				
			this.rfb = rfb;
		}
		
		private var handleTightData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				if (numColors == 0)
					rowSize *= bytesPerPixel;
				tightDataSize = rowSize * rfb.updateRectH;
				if (tightDataSize < TightMinToCompress) {
					if (numColors!=0) {
						handleTightIndexedData.bytesNeeded = tightDataSize;
						rfb.rfbStack.unshift(handleTightIndexedData);
					} else if (useGradient) {
						handleTightGradientData.bytesNeeded = tightDataSize;
						rfb.rfbStack.unshift(handleTightGradientData);
					} else {
						handleTightRawData.bytesNeeded = rfb.updateRectH*rfb.updateRectW*rfb.bytesPerPixel;
						rfb.rfbStack.unshift(handleTightRawData);
					}
				} else {
					rfb.rfbStack.unshift(
						handleTightZlibLen,
						handleTightZlibData);
				}
			});
		
		/* handle Tight data encoded with gradient filter
		*  very slow but seems to be used only if Jpeg is disable
		*  TODO: optimize it with BitmapData.applyFilter()
		*/
		private var handleTightGradientData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				logger.timeStart('handleTightGradientData');
				
				if (rfb.rawDataBuffer.length < tightDataSize) {
					rfb.rawDataBuffer.length = tightDataSize;
				}
				rfb.rawDataBuffer.position = 0;
				
				if (rfb.pixelsBuffer.length < 4*rfb.updateRectW*rfb.updateRectH) {
					rfb.pixelsBuffer.length = 4*rfb.updateRectW*rfb.updateRectH;
				}
				rfb.pixelsBuffer.position = 0;
				
				stream.readBytes(rfb.rawDataBuffer,0,tightDataSize);
				
				rfb.readPixels(
					rfb.rawDataBuffer,
					rfb.pixelsBuffer,
					rfb.updateRectW*rfb.updateRectH,
					rfb.bytesPerPixel != rfb.bytesPerPixelDepth);
					
				var index:int = 0;
				var x:int, y:int, c:int;
				
				index+=4;
				for (x=1; x<rfb.updateRectW; x++) {
					index++;
					rfb.pixelsBuffer[index] += rfb.pixelsBuffer[index-4];
					index++;
					rfb.pixelsBuffer[index] += rfb.pixelsBuffer[index-4];
					index++;
					rfb.pixelsBuffer[index] += rfb.pixelsBuffer[index-4];
					index++;
				}
				for (y=1; y<rfb.updateRectH; y++) {
					index++;
					rfb.pixelsBuffer[index] += rfb.pixelsBuffer[index-rfb.updateRectW*4];
					index++;
					rfb.pixelsBuffer[index] += rfb.pixelsBuffer[index-rfb.updateRectW*4];
					index++;
					rfb.pixelsBuffer[index] += rfb.pixelsBuffer[index-rfb.updateRectW*4];
					index++;
					for (x=1; x<rfb.updateRectW; x++) {
						index++;
						for (c=0; c<3; c++) {
							var est:int = rfb.pixelsBuffer[index-rfb.updateRectW*4]
								+ rfb.pixelsBuffer[index-4]
								- rfb.pixelsBuffer[index-rfb.updateRectW*4-4];
							if (est > 0xFF) {
								est = 0xFF;
							} else if (est < 0x00) {
								est = 0x00;
							}
							rfb.pixelsBuffer[index++] += est;
						}
					}
				}
				
				rfb.updateImage(
					rfb.updateRect,
					rfb.pixelsBuffer);
				
				/*var dx:int, dy:int, c:int;
				var prevRow:ByteArray = new ByteArray();
				prevRow.length = rfb.updateRectW;
				var thisRow:ByteArray = new ByteArray();
				thisRow.length = rfb.updateRectW;
				var pix:ByteArray = new ByteArray();
				pix.length = rfb.bytesPerPixel;
				var est:Array = new Array(rfb.bytesPerPixel);
				var tmp:ByteArray;
				
				for (c=0;c<rfb.updateRectW*rfb.bytesPerPixel;++c) {
					prevRow[c] = 0;
				}
		
				for (dy = 0; dy < rfb.updateRectH; dy++) {
		
					// First pixel in a row 
					for (c = 0; c < rfb.bytesPerPixel; c++) {
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
					
				logger.timeEnd('handleTightGradientData');
			});
		
		/* Handle tight data encoded in tight raw format
		*/
		private var handleTightRawData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				logger.timeStart('handleTightRawData');
				
				if (rfb.rawDataBuffer.length < tightDataSize) {
					rfb.rawDataBuffer.length = tightDataSize;
				}
				rfb.rawDataBuffer.position = 0;
				
				if (rfb.pixelsBuffer.length < 4*rfb.updateRectW*rfb.updateRectH) {
					rfb.pixelsBuffer.length = 4*rfb.updateRectW*rfb.updateRectH;
				}
				rfb.pixelsBuffer.position = 0;
				
				stream.readBytes(rfb.rawDataBuffer,0,tightDataSize);
				rfb.rawDataBuffer.position = 0;
				
				//readPixels2(rawDataBuffer,newImageData,updateRectW*updateRectH);
				rfb.readPixels(
					rfb.rawDataBuffer,
					rfb.pixelsBuffer,
					rfb.updateRectW*rfb.updateRectH,
					rfb.bytesPerPixel != rfb.bytesPerPixelDepth);
				
				rfb.updateImage(
					rfb.updateRect,
					rfb.pixelsBuffer);
					
				logger.timeEnd('handleTightRawData');
			});
		
		/* Handle tight data encoded in tight raw format
		*/
		private var handleTightIndexedData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				logger.timeStart('handleTightIndexedData2');
				
				var x:int;
				var y:int;
				var color:int;
				var dataPos:int=0;
				
				//output.text+="Indexed color data \n";
				if (numColors == 2) {
					// Only 2 colors, pixels are packed
					// TODO optimze this with BitmapData.paletteMap
					var data:int;
					var shift:int;
					
					if (rfb.rawDataBuffer.length < tightDataSize) {
						rfb.rawDataBuffer.length = tightDataSize;
					}
					rfb.rawDataBuffer.position = 0;
					
					if (rfb.pixelsBuffer.length < 4*rfb.updateRectW*rfb.updateRectH) {
						rfb.pixelsBuffer.length = 4*rfb.updateRectW*rfb.updateRectH;
					}
					rfb.pixelsBuffer.position = 0;
					
					var index:int = 0;
					
					stream.readBytes(rfb.rawDataBuffer,0,tightDataSize);
					
					for (y=rfb.updateRectY;y<rfb.updateRectY+rfb.updateRectH;y++) {
						shift = 8;
						for (x=rfb.updateRectX;x<rfb.updateRectX+rfb.updateRectW;x++) {
							if (shift == 8) {
								shift = 0;
								data = rfb.rawDataBuffer[dataPos++];
								//output.text+="data "+data.toString(2)+"\n";
							} else {
								data = data << 1;
							}
							
							//output.text+=x+" "+y+" "+tightPalette[data & 0x80]+"\n";
							color = tightPalette[(data >> 7) & 0x01];
							rfb.pixelsBuffer[index++] = 0xFF;
							rfb.pixelsBuffer[index++] = color>>16;
							rfb.pixelsBuffer[index++] = color>>8;
							rfb.pixelsBuffer[index++] = color;
							
							shift++;
						}
					}
					
					rfb.updateImage(
						rfb.updateRect,
						rfb.pixelsBuffer);
					
					logger.timeEnd('handleTightIndexedData2');
				} else {
					// Optimized decompression of a block of indexed pixels
					// TODO create a generic method to do this on RFB.as and use it
				
					logger.timeStart('handleTightIndexedDataP1');
					
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
					
					if (rfb.rawDataBuffer.length < tightDataSize + emptyFills) {
						rfb.rawDataBuffer.length = tightDataSize + emptyFills;
					}
					rfb.rawDataBuffer.position = 0;
					
					stream.readBytes(rfb.rawDataBuffer,0,tightDataSize);
					rfb.rawDataBuffer.position = 0;
					
					/*logger.log(rfb.updateRectX+" "+rfb.updateRectY+" "+rfb.updateRectW+" "+rfb.updateRectH);
					logger.log(tightDataSize+" ");
					logger.log(tmpBitmapWidth+" "+tmpBitmapHeigth);
					logger.log(rfb.rawDataBuffer.length+" ");*/
					
					var tmpBitmapDataIndexed:BitmapData = new BitmapData(tmpBitmapWidth,tmpBitmapHeigth,false,0xFFFFFFFF);
					var tmpBitmapDataIndexedAlpha:BitmapData = new BitmapData(tmpBitmapWidth,tmpBitmapHeigth,true,0xFFFFFFFF);
					var tmpBitmapDataFull:BitmapData = new BitmapData(tmpBitmapWidth*4,tmpBitmapHeigth,false,0xFFFFFFFF);
					
					tmpBitmapDataIndexed.setPixels(tmpBitmapDataIndexed.rect,rfb.rawDataBuffer);
					rfb.rawDataBuffer.position = 0;
					tmpBitmapDataIndexedAlpha.setPixels(tmpBitmapDataIndexed.rect,rfb.rawDataBuffer);
					
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
					
					var pixelsBuffer:BitmapData = tmpBitmapDataFull.getPixels(tmpBitmapDataFull.rect);
					pixelsBuffer.position = 0;
					rfb.updateImage(
						rfb.updateRect,
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
					logger.timeEnd('handleTightIndexedDataP1');
					
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
			});	
		
		private var handleTightFilter:DataHandler = new DataHandler(
			1,
			function(stream:IDataInput):void {
				var filterId:int = stream.readUnsignedByte();
				//output.text+="TightFilter : "+filterId+"\n";
				switch (filterId) {
					case TightFilterPalette :
						rfb.rfbStack.unshift(handleTightPaletteHeader);
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
			});
		
		private var handleTightPaletteHeader:DataHandler = new DataHandler(
			1,
			function(stream:IDataInput):void {
				numColors = stream.readUnsignedByte()+1;
				//output.text+="TightFilterPalette : "+numColors+"\n";
				handleTightPaletteColors.bytesNeeded = numColors*bytesPerPixel;
				rfb.rfbStack.unshift(handleTightPaletteColors);
			});
		
		private var handleTightPaletteColors:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				for (var i:int=0;i<numColors;i++) {
					tightPalette[i] = rfb.readPixel(stream,rfb.bytesPerPixel != rfb.bytesPerPixelDepth);
				}
				
				if (numColors == 2)
					rowSize = (rfb.updateRectW + 7) / 8;
			});
		
		private var handleTightZlibLen:DataHandler = new DataHandler(
			3,
			function(stream:IDataInput):void {
				tightZlibDataSize = readCompactLen(stream);
				handleTightZlibData.bytesNeeded = tightZlibDataSize;
			});
		
		
		/* Handle tight data compressed in a Zlib stream
		* TODO : improve Flash 9 support by using pseudo-multithreading
		*				function has to be split in small ones taking less than 20ms each
		*/
		private var handleTightZlibData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				logger.timeStart('handleTightZlibData');
				
				if (compressedBuffer.length < tightZlibDataSize) {
					compressedBuffer.length = tightZlibDataSize;
				}
				/*if (uncompressedBuffer.length < tightDataSize) {
					uncompressedBuffer.length = tightDataSize;
				}*/
				
				stream.readBytes(compressedBuffer,0,tightZlibDataSize);
				/*var zlibData:Array = new Array(handleTightZlibData.bytesNeeded);
				var tightData:Array = new Array(tightDataSize);
				var i:int;*/
				
				/*for (i=0;i<zlibData.length;i++) {
					zlibData[i]=stream.readUnsignedByte();
				}*/
				var streamId:int = tightCode & 0x03;
				var inflater:Inflater = tightInflaters[streamId];
				if (inflater == null) {
					inflater = new Inflater();
					tightInflaters[streamId] = inflater;
				}
				
				//inflater.setInput(compressedBuffer,0,tightZlibDataSize);
				//uncompressedStream.length = tightDataSize;
				
				logger.timeStart('inflater');
				
				uncompressedBuffer = inflater.inflate(compressedBuffer,tightZlibDataSize, tightDataSize);
				//inflater.inflate(uncompressedBuffer,0,tightDataSize);
				logger.timeEnd('inflater');

				/*for (i=0;i<tightData.length;i++) {
					uncompressedStream.writeByte(tightData[i]);
				}
				uncompressedStream.position = 0;*/
				//uncompressedBuffer.position = 0;
				
				logger.timeEnd('handleTightZlibData');
				
				logger.timeStart('handlingTightZlibData');
				if (numColors!=0) {
					handleTightIndexedData.bytesNeeded = tightDataSize;
					handleTightIndexedData.call(uncompressedBuffer);
				} else if (useGradient) {
					handleTightGradientData.bytesNeeded = tightDataSize;
					handleTightGradientData.call(uncompressedBuffer);
				} else {
					handleTightRawData.bytesNeeded = rfb.updateRectH*rfb.updateRectW*rfb.bytesPerPixel;
					handleTightRawData.call(uncompressedBuffer);
				}
				logger.timeEnd('handlingTightZlibData');
			});	
			
		private var handleTightFill:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				var color:uint = rfb.readPixel(stream,rfb.bytesPerPixel != rfb.bytesPerPixelDepth);
				var rect:Rectangle = new Rectangle(
					rfb.updateRectX,
					rfb.updateRectY,
					rfb.updateRectW,
					rfb.updateRectH);
				rfb.updateImageFillRect(
					rfb.updateRect,
					color);
			});
			
		private var handleTightJpegLen:DataHandler = new DataHandler(
			3,
			function(stream:IDataInput):void {
				handleTightJpegData.bytesNeeded = readCompactLen(stream);
			});
			
		private var handleTightJpegData:DataHandler = new DataHandler(
			0,
			function(stream:IDataInput):void {
				logger.timeStart('handleTightJpegData');
				
				if (rfb.rawDataBuffer.length < tightDataSize) {
					rfb.rawDataBuffer.length = tightDataSize;
				}
				rfb.rawDataBuffer.position = 0;
				
				stream.readBytes(rfb.rawDataBuffer,0,handleTightJpegData.bytesNeeded);
				
				jpgLoader.loadBytes(rfb.rawDataBuffer);
				
				jpgLoader.contentLoaderInfo.addEventListener(Event.COMPLETE,handleTightJpegComplete);
				
				rfb.pause(stream);
			});		
		
		private function handleTightJpegComplete(event:Event):void {
			var jpegImage:BitmapData = Bitmap(jpgLoader.content).bitmapData;
				
			rfb.updateImage(
				rfb.updateRect,
				jpegImage.getPixels(jpegImage.rect)
				);
			
			jpgLoader.unload();
			
			logger.timeEnd('handleTightJpegData');
			
			rfb.resume();
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