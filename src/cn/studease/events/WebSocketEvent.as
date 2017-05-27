package cn.studease.events
{
	import flash.events.Event;
	import flash.utils.getQualifiedClassName;
	
	import cn.studease.model.Config;

	public dynamic class WebSocketEvent extends Event
	{
		public static const FRAME_DATA:String = 'frameData';
		public static const ERROR:String = 'error';
		
		
		public var id:String;
		public var version:String;
		
		private var _data:Object;
		
		
		public function WebSocketEvent(type:String, data:Object = null)
		{
			super(type, false, false);
			
			id = getQualifiedClassName(this.target);
			version = Config.VERSION;
			
			_data = data;
			
			for (var i:String in data) {
				if (this.hasOwnProperty(i) == false) {
					this[i] = data[i];
				}
			}
		}
		
		override public function clone():Event {
			return new WebSocketEvent(type, _data);
		}
		
		override public function toString():String {
			return '[WebSocketEvent type="' + type + '" id="' + id + '" version="' + version + '" data=' + _data.toString() + ']';
		}
	}
}