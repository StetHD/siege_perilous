SRC = src

all:    subdirs

subdirs: 
	cd ${SRC}; make

# remove all the code
clean: 
	rm -rf ebin/*.beam erl_crash.dump
	rm -f *~
	rm -f src/*~
	rm -f ebin/*~
	rm -f include/*~
	rm -f src/*.beam
