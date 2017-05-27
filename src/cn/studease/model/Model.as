package cn.studease.model
{
	import flash.events.EventDispatcher;
	
	public class Model extends EventDispatcher
	{
		protected var _config:Config;
		protected var _state:String;
		
		
		public function Model(cfg:Object)
		{
			_config = new Config(cfg);
			_state = States.CLOSE;
		}
		
		
		public function get config():Config {
			return _config;
		}
		public function set config(cfg:Config):void {
			_config = cfg;
		}
		
		public function set state(value:String):void {
			_state = value;
		}
		public function get state():String {
			return _state;
		}
	}
}