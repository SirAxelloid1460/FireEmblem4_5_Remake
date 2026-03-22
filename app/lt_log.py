import sys, os
import logging

from app.constants import VERSION

# Taken from: https://stackoverflow.com/a/61043789
# Maxxim's answer
class LogFormatter(logging.Formatter):
    COLOR_CODES = {
        logging.CRITICAL: "\033[1;35m", # bright/bold magenta
        logging.ERROR: "\033[1;31m", # bright/bold red
        logging.WARNING: "\033[1;33m", # bright/bold yellow
        logging.INFO: "\033[0;37m", # white / light gray
        logging.DEBUG: "\033[1;30m", # bright/bold black / dark gray
    }

    RESET_CODE = "\033[0m"

    def __init__(self, color: bool, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.color: bool = color

    def format(self, record, *args, **kwargs):
        if self.color and record.levelno in self.COLOR_CODES:
            record.color_on = self.COLOR_CODES[record.levelno]
            record.color_off = self.RESET_CODE
        else:
            record.color_on = ""
            record.color_off = ""
        return super().format(record, *args, **kwargs)

# Setup logging
def setup_logging(console_log_output, console_log_level, console_log_color, logfile_file, logfile_log_level, logfile_log_color, log_line_template):
    logger = logging.getLogger()

    logger.setLevel(logging.DEBUG)

    console_log_output = console_log_output.lower()
    if console_log_output == "stdout":
        console_log_output = sys.stdout
    elif console_log_output == "stderr":
        console_log_output = sys.stderr
    else:
        print("Failed to set console output: invalid output: '%s'" % console_log_output)
        return False
    console_handler = logging.StreamHandler(console_log_output)

    # Set console log level
    try:
        console_handler.setLevel(console_log_level.upper())
    except Exception as exception:
        print("Failed to set console log level: invalid level: '%s'" % console_log_level)
        print(exception)
        return False

    # Create and set formatter, add console handler to logger
    console_formatter = LogFormatter(fmt=log_line_template, color=console_log_color)
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    # Create log file handler
    try:
        logfile_handler = logging.FileHandler(logfile_file, 'w', 'utf-8')
    except Exception as exception:
        print("Failed to set up log file: %s" % str(exception))
        return False

    # Set log file log level
    try:
        logfile_handler.setLevel(logfile_log_level.upper())
    except:
        print("Failed to set log file log level: invalid level: '%s'" % logfile_log_level)
        return False

    # Create and set formatter, add log file handler to logger
    logfile_formatter = LogFormatter(fmt=log_line_template, color=logfile_log_color)
    logfile_handler.setFormatter(logfile_formatter)
    logger.addHandler(logfile_handler)

    return True

def create_debug_log():
    """
    Increments all old debug logs in number
    Destroys logs older than 5 runs
    """
    counter = 5  # traverse backwards, so we don't overwrite older logs
    while counter > 0:
        fn = 'saves/debug.log.' + str(counter)
        if os.path.exists(fn):
            if counter == 5:
                os.remove(fn)
            else:
                os.rename(fn, 'saves/debug.log.' + str(counter + 1))
        counter -= 1

def create_logger() -> bool:
    try:
        create_debug_log()
    except WindowsError:
        print("Error! Debug logs in use -- Another instance of this is already running!")
        return None
    except PermissionError:
        print("Error! Debug logs in use -- Another instance of this is already running!")
        return None
    success = setup_logging(console_log_output="stdout", console_log_level="warning", console_log_color=False,
                            logfile_file='saves/debug.log.1', logfile_log_level="debug", logfile_log_color=False,
                            log_line_template="%(color_on)s%(relativeCreated)d %(levelname)7s:%(module)16s: %(message)s")
    if not success:
        print("Failed to setup logging")
        return False
    logging.info('*** Lex Talionis Engine Version %s ***' % VERSION)
    return True
