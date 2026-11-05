/*
 *    This file is part of the Distant Horizons mod
 *    licensed under the GNU LGPL v3 License.
 *
 *    Copyright (C) 2020 James Seibel
 *
 *    This program is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU Lesser General Public License as published by
 *    the Free Software Foundation, version 3.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU Lesser General Public License for more details.
 *
 *    You should have received a copy of the GNU Lesser General Public License
 *    along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

package com.seibel.distanthorizons.core.util;

import com.seibel.distanthorizons.core.dependencyInjection.SingletonInjector;
import com.seibel.distanthorizons.core.wrapperInterfaces.config.ILangWrapper;

/**
 * Translates messages that are built in code, such as chat warnings.
 * Keys only exist in the languages that translate them,
 * so English keeps using the text written at the call site.
 */
public final class LangUtil
{
	private LangUtil() { }

	/**
	 * Placeholders use "{0}" instead of "%s", since
	 * {@link ILangWrapper#getLang(String)} formats without arguments
	 * and would turn "%s" into a format error.
	 *
	 * @param fallback returned as-is when the key isn't available, IE
	 *                 for English, before the language has loaded,
	 *                 or on a dedicated server which doesn't have MC's I18n class.
	 */
	public static String translateOr(String key, String fallback, Object... args)
	{
		String translated;
		try
		{
			ILangWrapper lang = SingletonInjector.INSTANCE.get(ILangWrapper.class);
			if (lang == null || !lang.langExists(key))
			{
				return fallback;
			}
			translated = lang.getLang(key);
		}
		catch (Exception | LinkageError e)
		{
			return fallback;
		}

		for (int i = 0; i < args.length; i++)
		{
			translated = translated.replace("{" + i + "}", String.valueOf(args[i]));
		}
		return translated;
	}

}
