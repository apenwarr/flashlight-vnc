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
	PixelFormat structure	
*/

package com.wizhelp.flashlight.rfb
{
	public class RFBPixelFormat
	{
		public static const FORMAT_16BPP:RFBPixelFormat = new RFBPixelFormat({
			bitsPerPixel: 16,
		    depth: 16,
		    bigEndian: false,
		    trueColour: true,
		    redMax: 31,
		    greenMax: 31,
		    blueMax: 63,
		    redShift: 11,
		    greenShift: 6,
		    blueShift: 0
		});
		
		public static const FORMAT_24BPP:RFBPixelFormat = new RFBPixelFormat({
			bitsPerPixel: 32,
		    depth: 24,
		    bigEndian: false,
		    trueColour: true,
		    redMax: 255,
		    greenMax: 255,
		    blueMax: 255,
		    redShift: 16,
		    greenShift: 8,
		    blueShift: 0
		});
		
		public var bitsPerPixel:int;
		public var depth:int;
		public var bigEndian:Boolean;
		public var trueColour:Boolean;
		public var redMax:int;
		public var greenMax:int;
		public var blueMax:int;
		public var redShift:int;
		public var greenShift:int;
		public var blueShift:int;
		
		public function RFBPixelFormat(initObject:Object = null) {
			if (initObject!=null) {
				bitsPerPixel = initObject.bitsPerPixel;
				depth = initObject.depth;
				bigEndian = initObject.bigEndian;
				trueColour = initObject.trueColour;
				redMax = initObject.redMax;
				greenMax = initObject.greenMax;
				blueMax = initObject.blueMax;
				redShift = initObject.redShift;
				greenShift = initObject.greenShift;
				blueShift = initObject.blueShift;
			}
		}
	}
}