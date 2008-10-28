package com.screentoaster.utils.srt
{

	
	public class SRTReader
	{
		public static  function read(srtData:String):Array {
			// remove carriage return
			srtData = srtData.split('\r').join('');
			
			var subtitles:Array = new Array();
			
			 var lines:Array = srtData.split('\n');
			
			while (lines.length > 0) {
				// eat empty lines
				while (String(lines[0])=='') {
					lines.shift();
				}
				if (lines.length == 0) break;
				
				var subNumber:int;
				var subStart:int;
				var subEnd:int;
				var subWait:int = -1;
				var subText:Array = new Array();
				
				try {
					if (lines.length == 0) throw new Error("Unexpected end of STR");
					subNumber = int(lines.shift());
				} catch (e:Error) {
					throw new Error("Error when reading STR file : cannot parse subtitle number "+e);
				}
				
				try {
					if (lines.length == 0) throw new Error("Unexpected end of STR");
					var arr:Array = String(lines.shift()).split(' ');
					
					subStart = parseTime(arr.shift());
					if (arr.shift() != '-->') throw new Error('Bad delimiter between times');
					subEnd = parseTime(arr.shift());
					
					while (arr.length > 0) {
						var arr1:Array = String(arr.shift()).split(':');
						if (String(arr1.shift()).toLowerCase() == 'wait') {
							subWait = int(arr1.shift());
						}
					}
				} catch (e:Error) {
					throw new Error("Error when reading STR file : cannot parse info line "+e);
				}
				
				var textLine:String = lines.shift();
				while (textLine != '') {
					subText.push(textLine);
					
					if (lines.length == 0) break;
					textLine = lines.shift();
				}
				
				var subtitle:Subtitle = new Subtitle(subStart,subEnd,subText.join('\n'),subWait);
				subtitles.push(subtitle);
			}
			
			return subtitles;
		}
		
		private static  function parseTime(str:String):int {
			var arr1:Array = str.split(',');
			var arr2:Array = String(arr1.shift()).split(':');
			
			var result:int = int(arr2.shift());
			
			while (arr2.length >0) {
				result *= 60;
				result += int(arr2.shift());
			}
			
			result *= 1000;
			
			if (arr1.length >0) result += int(arr1.shift());
			
			return result;
		}
	}
}