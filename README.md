Это коллекция контуров, которые я использую для точной вырезки стран
и регионов из бОльших дампов, либо дампов, в которые попадают части
соседних регионов.

- contours.osm содержит контуры в виде обычных OSM полигонов либо
  мультиполигонов с тэгом name, его можно редактировать JOSM'ом
- osm2poly.pl конвертирует его в .poly файлы, понятные osmosis'у
  - для каждого контура создаётся .poly файл с названием из тэга
    name
  - скрипт зависит от модуля XML::Parser
  - скрипт обрабатывает .osm файл переданный в первом аргументе;
    вызванный без аргументов, он обрабатывает contours.osm в своей
    директории

======================================================================

This is a collection of contours I use for precise cutting countries
and regions out of larger OSM data dumps.

- contours.osm contains contours as a plain OSM data: ways and
  multipolygons with name tag. It may be edited in JOSM
- osm2poly.pl coverts it into a set of .poly files which may later
  be used with osmosis
  - for each contour, .poly file is created named after its name tag
  - script needs XML::Parser perl module
  - script processes .osm file provided in a first argument;
    without arguments, it processes contours.osm from directory where
    the script itself is located
