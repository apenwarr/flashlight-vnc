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

/**
 *  This class stores a VNC action
*/

package com.wizhelp.flashlight.vnc
{
	public dynamic class VNCAction {
		public static const UNLOCK_IMAGE:int = 5;
		public static const UPDATE_IMAGE:int = 0;
		public static const UPDATE_IMAGE_FILL_RECT:int = 1;
		public static const UPDATE_IMAGE_COPY_RECT:int = 2;
		public static const UPDATE_CURSOR_SHAPE:int = 3;
		public static const UPDATE_CURSOR_POS:int = 4;	
		public static const UPDATE_IMAGE_JPEG:int = 6;	    
		
		public var actionType:int;
		public var actionTime:int;
		
		public function VNCAction(actionType:int,actionTime:int) {
			this.actionTime = actionTime;
			this.actionType = actionType;
		}
	}
}