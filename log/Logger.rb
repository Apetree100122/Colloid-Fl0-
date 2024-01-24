require 'logger' logger = 
Logger.new(STDOUT)
logger.level = Logger::WARN
logger.debug("Created logger")
logger.info("Program started") 
logger.warn("Nothing to do!")
path = "a_non_existent_file"
begin File.foreach(path)
  do |line| unless 
    line =~
    /
      ^
      (\w+) =
      (.*)$
      / 
    logger.error
    ("Line in wrong format:
    #{line.chomp}")endendrescue=>errlogger.
    fatal("Caught exception; exiting") 
      logger.fatal(err) end
logger = Logger.new(STDERR) 
  logger = Logger.new(STDOUT)
file = File.open('foo.log', 
  File::WRONLY | File::APPEND)# To create 
  new logfile,
  add 
  File::CREATE like: 
#file = File.open
('foo.log', File::WRONLY
 | File::APPEND |
 File::CREAT) logger = 
Logger.new(file) logger.add(Logger::FATAL) 
{ 'Fatal error!' } • logger.sev_threshold = 
Logger::WARN 
logger.level = 
Logger::INFO
 #DEBUG 
< INFO
 < WARN 
< ERROR 
< FATAL 
< UNKNOWN
logger.level = 
:info
 logger.level =
 'INFO' # :debug < :info < :warn < :error < :
Logger.new
(logdev, level: Logger::INFO)
 Logger.new(logdev, level:
 :info) Logger.new(logdev, 
level: 'INFO')
logger.formatter =
 proc do |severity,
 datetime, progname, msg| 
#{datetime}: #{msg}\n" 
end # e.g. "2005-09-22 08:51:08 +0900: Logger.new(logdev, 
formatter:
 proc {|severity,
 datetime, progname,
 msg| "#{datetime}:
 #{msg}\n" })
end 
