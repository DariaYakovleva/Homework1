# Домашняя работа 1

Результаты лежат по адресу:
https://docs.google.com/spreadsheets/d/1RkdAmAbarzMfQUTWLhkFn7lcVD1nS7BVp8vrbFnPmV4/edit?usp=sharing

Дополнение:
все управляющие последовательности удовлетворяют регулярному выражению
```
%([0-+ ]*)([1-9][0-9]*)?(ll)?(u|i|d|%)
```
Если тип — %, то флаги, ширина поля и размер данных игнорируются, просто выводится знак %.
Например, последовательность
```
%+++ll%
```
допустима и выводит %, а
```
%ll %
```
недопустима.