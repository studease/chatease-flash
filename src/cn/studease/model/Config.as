package cn.studease.model
{
	import cn.studease.utils.Logger;

	public dynamic class Config
	{
		private static const _version:String = '1.0.00';
		private static var _logger:String = Logger.LOG;
		
		private var _id:String = 'chat';
		private var _url:String = 'ws://127.0.0.1/ch1?token=123456';
		
		
		public function Config(cfg:Object)
		{
			for (var i:String in cfg) {
				if (this.hasOwnProperty(i)) {
					this[i] = cfg[i];
				}
			}
			
			if (cfg.debug === true) {
				_logger = Logger.DEBUG;
			}
		}
		
		public function get version():String {
			return _version;
		}
		public static function get VERSION():String {
			return _version;
		}
		
		public static function get LOGGER():String {
			return _logger;
		}
		
		public function set id(x:String):void {
			_id = x;
		}
		public function get id():String {
			return _id;
		}
		
		public function set url(x:String):void {
			_url = x;
		}
		public function get url():String {
			return _url;
		}
	}
}