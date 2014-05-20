install:
	pip install -r requirements.txt
	touch .slipstream-build-all
	mvn clean install

run:
	foreman start
