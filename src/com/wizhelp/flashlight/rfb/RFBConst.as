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
	Constants of RFB
*/

package com.wizhelp.flashlight.rfb
{
	public class RFBConst
	{
		// Supported authentication types
		public static const SecTypeInvalid:int = 0;
		public static const SecTypeNone:int = 1;
		public static const SecTypeVncAuth:int = 2;
		public static const SecTypeTight:int   = 16;
		
 		// VNC authentication results
		public static const VncAuthOK:int      = 0;
		public static const VncAuthFailed:int  = 1;
		public static const VncAuthTooMany:int = 2;
		
		  // Server-to-client messages
		public static const FramebufferUpdate:int    	 = 0;
		public static const SetColourMapEntries:int 	 = 1;
		public static const Bell:int                	 = 2;
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

	}
}