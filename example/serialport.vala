using GLib;
using Gee;
using LibSerialPort;

namespace Test
{
    public interface SerialPortObserver : GLib.Object
    {
        public abstract void data_report(uint8[] data, int size);
    }

    public interface SerialPortSubject : GLib.Object
    {
        public abstract bool register_observer(SerialPortObserver observer);
        public abstract bool unregister_observer(SerialPortObserver observer);
        public abstract void notify_observers(uint8[] data, int len);
    }

    public class SerialPort : GLib.Object, SerialPortSubject
    {
        private Port port;
        private Cancellable watch_cancel = new GLib.Cancellable();
        private bool is_watching = false;
        private ArrayList<SerialPortObserver> observer_list = new ArrayList<SerialPortObserver>();
	        
        public string name { get; construct set; }
        
        public static string[] @enum()
        {
            string[] list = {};

            var ports = Port.@enum();

            foreach(unowned Port port in ports)
            {
                list += port.name();
            }

            return list;
        }

        private int watch_thread()
        {
            int bytes_read = 0;
            uint8 buffer[1024] = {0};
            EventSet event_set;

            EventSet.@new(out event_set);

            event_set.add_port(this.port, EventMask.RX_READY);
            
            this.is_watching = true;

            do
            {
                if(Return.OK == event_set.wait(200))
                {
                    bytes_read = this.port.nonblocking_read(buffer);
                    
                    if(bytes_read > 0)
                    {
                        this.notify_observers(buffer[0:bytes_read], bytes_read);
                    }
                }
            }
            while(false == this.watch_cancel.is_cancelled());
            
            this.is_watching = false;

            return 0;
        }
        
        public SerialPort(string name)
        {
            Object(name : name);

            if (Return.OK != Port.new_by_name(name, out this.port))
            {
                print("The serialport %s not exist in your system.\n", name);
            }
        }
        
        public bool open()
        {
            if (Return.OK != this.port.open(OpenMode.READ_WRITE))
            {
                print("Open the serialport %s fail, please insure it exist in your system and not be in used.\n", name);
                return false;
            }
            
            try
            {
                new Thread<int>.try ("SerialPortIoStream Watch Data", this.watch_thread);
            }
            catch(Error error)
            {
                print ("serialport try new thread fail, %s\n", error.message);
                return false;
            }
            
            watch_cancel.reset();
            
            return true;
        }
        
        public void close()
        {
            this.watch_cancel.cancel();
            
            while(true == this.is_watching)
            {
                Thread.usleep(100);
            }
            
            this.port.close();
        }
        
        public bool set_config(Config config)
        {
            if(Return.OK != this.port.set_config(config))
            {
                return false;
            }
            
            return true;
        }
        
        public bool get_config(Config config)
        {
            if(Return.OK != this.port.get_config(config))
            {
                return false;
            }
            
            return true;
        }
        
        public bool set_baudrate(int baudrate)
        {
            if(Return.OK != this.port.set_baudrate(baudrate))
            {
                return false;
            }
            
            return true;
        }
        
        public bool set_bits(int bits)
        {
            if(Return.OK != this.port.set_bits(bits))
            {
                return false;
            }
            
            return true;
        }
        
        public bool set_stopbits(int stopbits)
        {
            if(Return.OK != this.port.set_stopbits(stopbits))
            {
                return false;
            }
            
            return true;
        }
        
	    public void write(uint8[] data)
	    {
		    this.port.blocking_write(data , 0);
	    }
            
        public bool register_observer(SerialPortObserver observer)
        {
            if(false == observer_list.contains(observer))
            {
                observer_list.add(observer);
                return true;
            }
            
            return false;
        }

        public bool unregister_observer(SerialPortObserver observer)
        {
            if(true == observer_list.contains(observer))
            {
                observer_list.remove(observer);
                return true;
            }
            
            return false;
        }
        
        public void notify_observers(uint8[] data, int len)
        {
            observer_list.foreach((observer) =>{
                observer.data_report(data, len);
                return true;
            });
        }
    }

	class Test : GLib.Object, SerialPortObserver
	{
		public void data_report(uint8[] data, int size)
		{
			//here we consider the data is string, ignore the size
			GLib.print((string)data);
		}

		static int main(string[] args)
		{
			//enum the ports
			var port_names = SerialPort.@enum();

			foreach(var port_name in port_names)
			{
				GLib.print(@"port_name = $port_name\n");
			}

			//open port
			var port = new SerialPort("/dev/ttyS0");

			if(!port.open())
			{
				//may be not have permission
				GLib.print("port open failed.");
				return 0;
			}

			//if any data coming, it will show in console
			port.register_observer(new Test());

			port.close();	

			return 0;
		}
	}
}
