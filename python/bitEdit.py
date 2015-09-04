#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import Tkinter
import tkFont

class CBitEdit:
    def __init__(self, root, val, title=""):
        self.bitIndex = range(0, 32)
                   
        self.texts = []
        self.checks = []

        self.oldHexValStr = Tkinter.StringVar(value=self._toHexStr(val))
        self.newHexValStr = Tkinter.StringVar(value=self._toHexStr(val))
        self.oldDecValStr = Tkinter.StringVar(value=self._toDecStr(val))
        self.newDecValStr = Tkinter.StringVar(value=self._toDecStr(val))

        self.root = root
        self.frame = Tkinter.LabelFrame(self.root, text = title, padx = 10, pady = 10)

        font_height = 18
        self.font = tkFont.Font(family="mycode", size=font_height, weight="normal")

        self._initShowCtrl()
        self._initBitCtrl()
        self.frame.pack(padx = 10, pady = 10)

    def _setBit(self, event, pos):
        # print event.x
        self._showBit(pos, self.texts[pos]['text'] != '1')
        val = self._texts2Val()
        self.newHexValStr.set(self._toHexStr(val))
        self.newDecValStr.set(self._toDecStr(val))

    def _reset(self, event):
        self.newHexValStr.set(self.oldHexValStr.get())
        self.newDecValStr.set(self.oldDecValStr.get())
        self._showBits(int(self.newHexValStr.get(), 16))
        for check in self.checks:
            check.deselect()

    def _copy(self, event, var):
        self.frame.clipboard_clear()
        self.frame.clipboard_append(var.get())

    def _toHexStr(self, val):
        return '0x%08X' % (val & 0xffffffff)

    def _toDecStr(self, val):
        return '%d' % (val & 0xffffffff)

    def _texts2Val(self):
        val = 0
        for i in range(0, len(self.texts)):
            if self.texts[i].cget("text") == '1':
                val |= (1 << i)
        return val

    def _showBit(self, pos, state):
        if state:
            self.texts[pos].configure(text='1', fg='black')
        else:
            self.texts[pos].configure(text='0', fg='gray')

    def _showBits(self, val):
        for i in range(0, len(self.texts)):
            self._showBit(i, val & (1 << i))

    def getOldVal(self):
        return int(self.oldHexValStr.get(), 16)

    def getNewVal(self):
        return int(self.newHexValStr.get(), 16)

    def _initShowCtrl(self):
        frame = Tkinter.Frame(self.frame)
        oldHexEntry = Tkinter.Entry(frame, font=self.font, width=10, fg='black', bg='white', state='readonly')
        oldDecEntry = Tkinter.Entry(frame, font=self.font, width=10, fg='black', bg='white', state='readonly')
        newHexEntry = Tkinter.Entry(frame, font=self.font, width=10, fg='green', bg='white', state='readonly')
        newDecEntry = Tkinter.Entry(frame, font=self.font, width=10, fg='green', bg='white', state='readonly')
        oldHexEntry['textvariable'] = self.oldHexValStr
        newHexEntry['textvariable'] = self.newHexValStr
        oldDecEntry['textvariable'] = self.oldDecValStr
        newDecEntry['textvariable'] = self.newDecValStr
        self.btnCopyHex = Tkinter.Button(frame, font=self.font, text="CopyHex", height=1)
        self.btnCopyDec = Tkinter.Button(frame, font=self.font, text="CopyDec", height=1)
        self.btnReset = Tkinter.Button(frame, font=self.font, text="Reset",height=1)
        oldHexEntry.pack(side=Tkinter.LEFT, padx=5)
        oldDecEntry.pack(side=Tkinter.LEFT, padx=5)
        newHexEntry.pack(side=Tkinter.LEFT, padx=5)
        newDecEntry.pack(side=Tkinter.LEFT, padx=5)
        self.btnCopyHex.pack(side=Tkinter.LEFT, padx=5)
        self.btnCopyDec.pack(side=Tkinter.LEFT, padx=5)
        self.btnReset.pack(side=Tkinter.LEFT, padx=5)
        self.btnCopyHex.bind('<Button-1>', lambda event,var=self.newHexValStr: self._copy(event, var))
        self.btnCopyDec.bind('<Button-1>', lambda event,var=self.newDecValStr: self._copy(event, var))
        self.btnReset.bind('<Button-1>', self._reset)
        frame.pack(side=Tkinter.TOP)

    def _initBitCtrl(self):
        for str in self.bitIndex:
            frame = Tkinter.Frame(self.frame)
            c = Tkinter.Checkbutton(frame, text=str, font=self.font, width=2, indicatoron = False)
            c['selectcolor'] = 'red'
            c.pack(side=Tkinter.TOP)
            self.checks.append(c)
            t = Tkinter.Label(frame, font=self.font, width=2, bg='white')
            t.pack(side=Tkinter.BOTTOM)
            self.texts.append(t)
            frame.pack(side=Tkinter.RIGHT)
            for i in range(0, len(self.checks)):
                self.checks[i].bind('<Button-1>', lambda event,pos=i: self._setBit(event, pos))
        self._showBits(int(self.newHexValStr.get(), 16))


class CGui:
    def __init__(self, vals):
        self.root = Tkinter.Tk()
        self.root.title('Bit Edit')
        self.root.bind('<KeyRelease-Escape>', self.quit)
        self.bitEdits = []
        for val in vals:
            self.bitEdits.append(CBitEdit(self.root, val))

    def start(self):
        self.root.mainloop()

    def quit(self, event):
        # event.widget.quit()
        print("-" * 80)
        index = 1
        for edit in self.bitEdits:
            print("%2d : new : 0x%08x \t old : 0x%08x" % (index, edit.getOldVal(), edit.getNewVal()))
            index += 1
        print("-" * 80)
        self.root.quit()


if __name__ == '__main__':
    argc = len(sys.argv)
    vals = []
    if  argc > 1:
        for i in range(1, argc):
            str = sys.argv[i].lower()
            if str[:2] == "0x":
                vals.append(int(str, 16))
            elif str[:2] == "0b":
                vals.append(int(str, 2))
            else:
                vals.append(int(str, 10))
    else:
        vals.append(0)

    gui = CGui(vals)
    gui.start()


