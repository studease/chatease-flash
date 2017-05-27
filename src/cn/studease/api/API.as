package cn.studease.api
{
	import flash.events.IEventDispatcher;
	
	import cn.studease.model.Config;

	public interface API extends IEventDispatcher
	{
		function get version():String;
		function get config():Config;
		function get state():String;
		
		function connect():void;
		function send(text:String):void;
		function close():void;
	}
}