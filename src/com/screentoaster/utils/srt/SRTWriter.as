package com.screentoaster.utils.srt
{
	
	public class SRTWriter
	{
		public static function write(subtitles:Array):String {
			var result:Array = new Array();
			
			var subtitle:Subtitle;
			var index:int = 1;
			for each (subtitle in subtitles) {
				result.push(String(index++));
				result.push(
					writeTime(subtitle.showTime) + ' --> ' +
					writeTime(subtitle.hideTime) +
					(subtitle.waitTime > 0 ? ' WAIT:'+subtitle.waitTime : ''));
				result.push(subtitle.text);
				result.push('');
			}
			
			return result.join('\n');
		}
		
		private static function writeTime(time:int):String {
			var milli:int = time % 1000;
			time = time/1000;
			
			var secs:int = time % 60;
			time = time / 60;
			
			var mins:int = time % 60;
			var hours:int = time / 60;
			
			var result:String = 
				(hours > 9 ? '' : '0') + hours + ':' +
				(mins > 9 ? '' : '0') + mins + ':' +
				(secs > 9 ? '' : '0') + secs + ',' +
				(milli > 99 ? '' : '0') + (milli > 9 ? '' : '0') + milli;
			return result;
		}

	}
}